// src/pages/CuadernoEntrenamiento.jsx
import { useEffect, useState, useMemo } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
  Box,
  Paper,
  Typography,
  Stack,
  Button,
  Grid,
  Select,
  MenuItem,
  TextField,
  Divider,
  Snackbar,
  Alert,
  IconButton,
  CircularProgress
} from "@mui/material";
import ArrowBackIcon from "@mui/icons-material/ArrowBack";
import SaveIcon from "@mui/icons-material/Save";
import DeleteOutlineIcon from "@mui/icons-material/DeleteOutline";
import AddIcon from "@mui/icons-material/Add";
import API from "../services/api";

export default function CuadernoEntrenamiento() {
  const { id } = useParams(); // entrenamientoId
  const navigate = useNavigate();

  const [ent, setEnt] = useState(null);
  const [loading, setLoading] = useState(true);
  
  // Selección
  const [selectedSemanaIdx, setSelectedSemanaIdx] = useState(0);
  const [selectedDiaIdx, setSelectedDiaIdx] = useState(0);

  // Formulario (estado local para la sesión actual)
  // { [ejercicioIndex]: { series: [{peso, reps, rir}], notas: "" } }
  const [formData, setFormData] = useState({});
  const [comentarios, setComentarios] = useState("");

  const [saving, setSaving] = useState(false);
  const [toast, setToast] = useState({ open: false, sev: "success", msg: "" });

  // 1. Cargar Entrenamiento
  useEffect(() => {
    (async () => {
      try {
        const res = await API.get(`/entrenamientos/${id}`);
        setEnt(res.data);
      } catch (e) {
        console.error(e);
        setToast({ open: true, sev: "error", msg: "Error cargando entrenamiento" });
      } finally {
        setLoading(false);
      }
    })();
  }, [id]);

  // Objeto Semana/Dia actual
  const currentBlock = useMemo(() => {
    if (!ent) return null;
    const sem = ent.semanas?.[selectedSemanaIdx];
    const dia = sem?.dias?.[selectedDiaIdx];
    return { sem, dia };
  }, [ent, selectedSemanaIdx, selectedDiaIdx]);

  // Inicializar formulario cuando cambia el bloque seleccionado
  useEffect(() => {
    if (!currentBlock?.dia) return;
    const items = currentBlock.dia.items || [];
    const init = {};
    items.forEach((it, idx) => {
       // Pre-fill con las series planeadas
       // Si el plan dice 3 series, ponemos 3 filas vacías
       const numSeries = it.esquema?.series || 1;
       const seriesArr = Array.from({ length: numSeries }).map(() => ({ peso: "", reps: "", rir: "" }));
       init[idx] = {
         series: seriesArr,
         notas: ""
       };
    });
    setFormData(init);
    setComentarios("");
  }, [currentBlock]);

  // Manejadores de campos
  const handleSerieChange = (ejIdx, sIdx, field, val) => {
     // Validation: Block negative numbers
     if (val < 0) return;

     setFormData(prev => {
        const copy = { ...prev };
        const ejData = { ...copy[ejIdx] };
        const series = [...ejData.series];
        series[sIdx] = { ...series[sIdx], [field]: val };
        ejData.series = series;
        copy[ejIdx] = ejData;
        return copy;
     });
  };

  const handleNotaChange = (ejIdx, val) => {
    setFormData(prev => ({
        ...prev,
        [ejIdx]: { ...prev[ejIdx], notas: val }
    }));
  };

  const addSerie = (ejIdx) => {
      setFormData(prev => {
        const copy = { ...prev };
        const series = [...copy[ejIdx].series, { peso: "", reps: "", rir: "" }];
        copy[ejIdx].series = series;
        return copy;
     });
  };

  const removeSerie = (ejIdx, sIdx) => {
      setFormData(prev => {
        const copy = { ...prev };
        const series = copy[ejIdx].series.filter((_, i) => i !== sIdx);
        copy[ejIdx].series = series;
        return copy;
     });
  };

  const handleGuardar = async () => {
    if (!ent || !currentBlock?.dia) return;
    
    // Validation: Check for incomplete sets
    const items = currentBlock.dia.items || [];
    for (let idx = 0; idx < items.length; idx++) {
        const data = formData[idx];
        if (!data) continue;
        
        for (let sIdx = 0; sIdx < data.series.length; sIdx++) {
            const s = data.series[sIdx];
            // If any field is filled, ALL must be filled (except maybe RIR which is optional usually, but let's enforce weight/reps)
            const hasData = s.peso !== "" || s.reps !== "";
            // Strict check: Weight and Reps are required if the row is touched or exists
            if (hasData || (s.peso === "" && s.reps === "")) {
                 // If it has data, check completeness
                 if (hasData && (s.peso === "" || s.reps === "")) {
                     setToast({ open: true, sev: "warning", msg: `Faltan datos en el ejercicio ${idx + 1}, serie ${sIdx + 1}` });
                     return;
                 }
                 // Also block 0 if strict, or just empty strings
            }
        }
    }

    try {
        setSaving(true);
        // Construir payload
        // Mapeamos los ejercicios originales a la estructura del Registro
        const ejerciciosPayload = (currentBlock.dia.items || []).map((it, idx) => {
            const data = formData[idx];
            // Filtramos series vacías o convertimos
            const seriesLimpio = data.series
                .filter(s => s.peso !== "" && s.reps !== "") // Only keep complete sets
                .map(s => ({
                    peso: Number(s.peso) || 0,
                    reps: Number(s.reps) || 0,
                    rir: Number(s.rir) || 0
                }));
            
            return {
                ejercicio: it.ejercicio?._id || it.ejercicio, // ID si es populate
                ejercicioNombre: typeof it.ejercicio === 'object' ? it.ejercicio.nombre : "Ejercicio",
                series: seriesLimpio,
                notas: data.notas
            };
        });

        const payload = {
            entrenamientoId: ent._id,
            clienteId: ent.clienteId, // Asumiendo que viene en ent
            semanaNumero: currentBlock.sem.numero || (selectedSemanaIdx + 1),
            diaNombre: currentBlock.dia.nombre || `Día ${selectedDiaIdx + 1}`,
            ejercicios: ejerciciosPayload,
            comentarios
        };

        await API.post("/entrenamientos/registros", payload);
        setToast({ open: true, sev: "success", msg: "Sesión registrada correctamente" });
        // Opcional: navegar atrás o limpiar
        setTimeout(() => navigate(-1), 1500);

    } catch (e) {
        console.error(e);
        setToast({ open: true, sev: "error", msg: "Error al guardar el registro" });
    } finally {
        setSaving(false);
    }
  };

  if (loading) return <Box p={4}><CircularProgress /></Box>;
  if (!ent) return <Box p={4}>No se encontró el entrenamiento</Box>;

  return (
    <Box p={{ xs: 2, md: 4 }}>
      {/* HEADER */}
      <Paper elevation={0} sx={{ p: 2, mb: 3, borderRadius: 3, border: "1px solid", borderColor: "divider" }}>
        <Stack direction="row" alignItems="center" spacing={2} mb={2}>
            <IconButton onClick={() => navigate(-1)}>
                <ArrowBackIcon />
            </IconButton>
            <Box>
                <Typography variant="h5" fontWeight={700}>Notebook: {ent.titulo}</Typography>
                <Typography variant="body2" color="text.secondary">Registra tus pesos y sensaciones</Typography>
            </Box>
        </Stack>

        <Grid container spacing={2}>
            <Grid item xs={6} md={3}>
                <Select
                    fullWidth
                    size="small"
                    value={selectedSemanaIdx}
                    onChange={(e) => { setSelectedSemanaIdx(e.target.value); setSelectedDiaIdx(0); }}
                >
                    {(ent.semanas || []).map((sem, i) => (
                        <MenuItem key={i} value={i}>Semana {sem.numero || i + 1}</MenuItem>
                    ))}
                </Select>
            </Grid>
            <Grid item xs={6} md={3}>
                <Select
                    fullWidth
                    size="small"
                    value={selectedDiaIdx}
                    onChange={(e) => setSelectedDiaIdx(e.target.value)}
                >
                    {(ent.semanas?.[selectedSemanaIdx]?.dias || []).map((dia, i) => (
                        <MenuItem key={i} value={i}>{dia.nombre || `Día ${i+1}`}</MenuItem>
                    ))}
                </Select>
            </Grid>
        </Grid>
      </Paper>

      {/* LISTA EJERCICIOS */}
      <Stack spacing={2}>
         {(currentBlock?.dia?.items || []).map((item, idx) => {
             const exName = typeof item.ejercicio === 'object' ? item.ejercicio.nombre : "Ejercicio";
             const currentData = formData[idx] || { series: [], notas: "" };

             return (
                 <Paper key={idx} elevation={0} sx={{ p: 2, borderRadius: 2, border: "1px solid", borderColor: "divider" }}>
                     <Typography variant="subtitle1" fontWeight={700} gutterBottom>{idx + 1}. {exName}</Typography>
                     
                     <Stack spacing={1} mb={2}>
                        {currentData.series.map((serie, sIdx) => (
                            <Grid container spacing={1} key={sIdx} alignItems="center">
                                <Grid item xs={1}>
                                    <Typography variant="caption" color="text.secondary">#{sIdx + 1}</Typography>
                                </Grid>
                                <Grid item xs={3}>
                                    <TextField 
                                        label="kg" 
                                        size="small" 
                                        type="number" 
                                        value={serie.peso} 
                                        onChange={(e) => handleSerieChange(idx, sIdx, 'peso', e.target.value)}
                                        onWheel={(e) => e.target.blur()}
                                    />
                                </Grid>
                                <Grid item xs={3}>
                                    <TextField 
                                        label="reps" 
                                        size="small" 
                                        type="number"
                                        value={serie.reps} 
                                        onChange={(e) => handleSerieChange(idx, sIdx, 'reps', e.target.value)}
                                        onWheel={(e) => e.target.blur()}
                                    />
                                </Grid>
                                <Grid item xs={3}>
                                    <TextField 
                                        label="RIR" 
                                        size="small" 
                                        type="number"
                                        value={serie.rir} 
                                        onChange={(e) => handleSerieChange(idx, sIdx, 'rir', e.target.value)}
                                        onWheel={(e) => e.target.blur()} 
                                    />
                                </Grid>
                                <Grid item xs={2}>
                                    <IconButton size="small" color="error" onClick={() => removeSerie(idx, sIdx)}>
                                        <DeleteOutlineIcon fontSize="small" />
                                    </IconButton>
                                </Grid>
                            </Grid>
                        ))}
                     </Stack>
                     
                     <Stack direction="row" spacing={2} alignItems="center">
                        <Button startIcon={<AddIcon />} size="small" onClick={() => addSerie(idx)}>Serie</Button>
                        <TextField 
                            placeholder="Notas del ejercicio..." 
                            size="small" 
                            fullWidth 
                            value={currentData.notas}
                            onChange={(e) => handleNotaChange(idx, e.target.value)}
                        />
                     </Stack>
                 </Paper>
             );
         })}
      </Stack>
      
      {/* GENERAL NOTES & SAVE */}
      <Paper elevation={0} sx={{ p: 2, mt: 3, borderRadius: 3, border: "1px solid", borderColor: "divider" }}>
          <TextField 
             label="Comentarios generales de la sesión"
             multiline
             minRows={2}
             fullWidth
             value={comentarios}
             onChange={(e) => setComentarios(e.target.value)}
             sx={{ mb: 2 }}
          />
          <Button 
            variant="contained" 
            size="large" 
            fullWidth 
            startIcon={<SaveIcon />}
            onClick={handleGuardar}
            disabled={saving}
          >
            {saving ? "Guardando..." : "Registrar Sesión"}
          </Button>
      </Paper>

      <Snackbar open={toast.open} autoHideDuration={4000} onClose={() => setToast({ ...toast, open: false })}>
        <Alert severity={toast.sev} variant="filled">{toast.msg}</Alert>
      </Snackbar>

    </Box>
  );
}
