// src/pages/EditarEntrenamiento.jsx
import { useEffect, useMemo, useRef, useState } from "react";
import {
  Box,
  Paper,
  Stack,
  Typography,
  Button,
  TextField,
  Grid,
  IconButton,
  Tooltip,
  Divider,
  Chip,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Table,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  Avatar,
  Snackbar,
  Alert,
  MenuItem,
  InputAdornment,
  Skeleton,
} from "@mui/material";

import AddIcon from "@mui/icons-material/Add";
import DeleteOutlineIcon from "@mui/icons-material/DeleteOutline";
import FitnessCenterIcon from "@mui/icons-material/FitnessCenter";
import CloseIcon from "@mui/icons-material/Close";
import SearchIcon from "@mui/icons-material/Search";
import PlaylistAddIcon from "@mui/icons-material/PlaylistAdd";
import TodayIcon from "@mui/icons-material/Today";
import FlagIcon from "@mui/icons-material/Flag";
import SaveIcon from "@mui/icons-material/Save";
import ContentCopyIcon from "@mui/icons-material/ContentCopy";
import DragIndicatorIcon from "@mui/icons-material/DragIndicator";
import ArrowBackIcon from "@mui/icons-material/ArrowBack";
import { useAuth } from "../context/AuthContext";
import { extractAsesorId } from "../utils/auth";

import { useNavigate, useParams } from "react-router-dom";
import API from "../services/api";

const headerGradient =
  "linear-gradient(180deg, rgba(246,247,251,0.7) 0%, rgba(255,255,255,1) 45%)";

const NIVELES = ["principiante", "intermedio", "avanzado"]; // opcional UI

export default function EditarEntrenamiento() {
  const { id } = useParams();
  const navigate = useNavigate();

  // --- Formulario raíz ---
  const [titulo, setTitulo] = useState("");
  const [objetivo, setObjetivo] = useState("");
  const [nivel, setNivel] = useState(""); // opcional
  const [activo, setActivo] = useState(true);
  const { user, token } = useAuth();
  const asesorId = useMemo(() => extractAsesorId(user, token), [user, token]);
  const [clienteId, setClienteId] = useState("");

  // --- Estructura del entrenamiento ---
  const [semanas, setSemanas] = useState([]);

  // --- Estado general ---
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [toast, setToast] = useState({ open: false, sev: "success", msg: "" });

  // --- Selector de ejercicio ---
  const [pickOpen, setPickOpen] = useState(false);
  const [pickTarget, setPickTarget] = useState({ semIdx: null, diaIdx: null, itemIdx: null });
  const [searchQ, setSearchQ] = useState("");
  const [equipo, setEquipo] = useState("");
  const [grupo, setGrupo] = useState("");
  const searchDebounce = useRef(null);
  const [exLoading, setExLoading] = useState(false);
  const [exList, setExList] = useState([]);

  const EQUIPOS = ["", "barra", "mancuernas", "maquina", "polea", "peso corporal", "kettlebell", "bandas", "otros"];
  const GRUPOS  = ["", "pecho", "espalda", "hombro", "brazo", "core", "pierna", "gluteo", "fullbody", "otros"];

  // ---------- Cargar entrenamiento ----------
  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        setLoading(true);
        const res = await API.get(`/entrenamientos/${id}`); // ideal con populate
        if (!mounted) return;

        const e = res.data || {};
        setTitulo(e.titulo || "");
        setObjetivo(e.objetivo || "");
        setActivo(e.activo !== false);
        setClienteId(e.clienteId || "");
        // opcional: si guardas "nivel" en algún lado
        setNivel(e.nivel || "");

        setSemanas(
          Array.isArray(e.semanas) && e.semanas.length
            ? e.semanas.map((s, si) => ({
                numero: s.numero || si + 1,
                dias: (s.dias || []).map((d) => ({
                  nombre: d.nombre || `Día`,
                  items: (d.items || []).map((it, idx) => ({
                    ejercicio: typeof it.ejercicio === "object" ? it.ejercicio._id || it.ejercicio : it.ejercicio,
                    ejercicioObj: typeof it.ejercicio === "object" ? it.ejercicio : null, // para mostrar nombre si vino populate
                    orden: typeof it.orden === "number" ? it.orden : idx,
                    grupoId: it.grupoId || "",
                    esquema: {
                      series: it?.esquema?.series ?? 3,
                      repsMin: it?.esquema?.repsMin ?? 8,
                      repsMax: it?.esquema?.repsMax ?? 12,
                      rir: it?.esquema?.rir ?? 1,
                      descanso: it?.esquema?.descanso ?? 90,
                      notas: it?.esquema?.notas || "",
                    },
                  })),
                })),
              }))
            : [{ numero: 1, dias: [{ nombre: "Día 1", items: [] }] }]
        );
      } catch (e) {
        console.error("GET /entrenamientos/:id", e);
        setToast({ open: true, sev: "error", msg: "No se pudo cargar el entrenamiento" });
      } finally {
        setLoading(false);
      }
    })();
    return () => { mounted = false; };
  }, [id]);

  // ---------- Helpers de estructura ----------
  const addSemana = () => {
    setSemanas((prev) => {
      const numero = (prev[prev.length - 1]?.numero || prev.length) + 1;
      return [...prev, { numero, dias: [{ nombre: "Día 1", items: [] }] }];
    });
  };
  const removeSemana = (i) => setSemanas((prev) => prev.filter((_, idx) => idx !== i));

  const addDia = (semIdx) => {
    setSemanas((prev) => {
      const copy = [...prev];
      const n = (copy[semIdx].dias?.length || 0) + 1;
      copy[semIdx].dias.push({ nombre: `Día ${n}`, items: [] });
      return copy;
    });
  };
  const removeDia = (semIdx, diaIdx) => {
    setSemanas((prev) => {
      const copy = [...prev];
      copy[semIdx].dias = copy[semIdx].dias.filter((_, i) => i !== diaIdx);
      return copy;
    });
  };

  const addItem = (semIdx, diaIdx) => {
    setSemanas((prev) => {
      const copy = [...prev];
      const items = copy[semIdx].dias[diaIdx].items || [];
      items.push({
        ejercicio: null,
        ejercicioObj: null,
        orden: items.length,
        grupoId: "",
        esquema: { series: 3, repsMin: 8, repsMax: 12, rir: 1, descanso: 90, notas: "" },
      });
      copy[semIdx].dias[diaIdx].items = items;
      return copy;
    });
  };
  const removeItem = (semIdx, diaIdx, itemIdx) => {
    setSemanas((prev) => {
      const copy = [...prev];
      const items = (copy[semIdx].dias[diaIdx].items || []).filter((_, i) => i !== itemIdx);
      copy[semIdx].dias[diaIdx].items = items.map((it, idx) => ({ ...it, orden: idx }));
      return copy;
    });
  };
  const moveItem = (semIdx, diaIdx, itemIdx, dir) => {
    setSemanas((prev) => {
      const copy = [...prev];
      const arr = copy[semIdx].dias[diaIdx].items || [];
      const newIdx = itemIdx + dir;
      if (newIdx < 0 || newIdx >= arr.length) return prev;
      const tmp = [...arr];
      const [m] = tmp.splice(itemIdx, 1);
      tmp.splice(newIdx, 0, m);
      copy[semIdx].dias[diaIdx].items = tmp.map((it, idx) => ({ ...it, orden: idx }));
      return copy;
    });
  };
  const setItemField = (semIdx, diaIdx, itemIdx, path, value) => {
    setSemanas((prev) => {
      const copy = [...prev];
      const it = copy[semIdx].dias[diaIdx].items[itemIdx];
      if (path.startsWith("esquema.")) {
        const key = path.split(".")[1];
        it.esquema = { ...it.esquema, [key]: value };
      } else {
        it[path] = value;
      }
      return copy;
    });
  };
  const cloneDia = (semIdx, diaIdx) => {
    setSemanas((prev) => {
      const copy = [...prev];
      const dia = copy[semIdx].dias[diaIdx];
      const nuevo = JSON.parse(JSON.stringify(dia));
      nuevo.items = (nuevo.items || []).map((it, idx) => ({ ...it, orden: idx }));
      const n = (copy[semIdx].dias?.length || 0) + 1;
      nuevo.nombre = `${dia.nombre} (copia ${n - diaIdx})`;
      copy[semIdx].dias.push(nuevo);
      return copy;
    });
  };

  // ---------- Búsqueda de ejercicios ----------
  const fetchEjercicios = async () => {
    setExLoading(true);
    try {
      const params = {
        q: (searchQ || "").trim() || undefined,
        equipo: equipo || undefined,
        grupo: grupo || undefined,
        sort: "nombre",
        order: "asc",
        limit: 30,
      };
      const res = await API.get("/ejercicios", { params });
      const data = res.data;
      const list = Array.isArray(data) ? data : data?.items || [];
      setExList(list);
    } catch (e) {
      console.error("Buscar ejercicios", e);
      setExList([]);
    } finally {
      setExLoading(false);
    }
  };
  useEffect(() => { fetchEjercicios(); /* carga inicial */ }, []);
  useEffect(() => {
    if (searchDebounce.current) clearTimeout(searchDebounce.current);
    searchDebounce.current = setTimeout(fetchEjercicios, 350);
    return () => clearTimeout(searchDebounce.current);
  }, [searchQ, equipo, grupo]);

  const openPickerFor = (semIdx, diaIdx, itemIdx) => {
    setPickTarget({ semIdx, diaIdx, itemIdx });
    setPickOpen(true);
  };
  const pickEjercicio = (ex) => {
    const { semIdx, diaIdx, itemIdx } = pickTarget;
    if (semIdx == null) return;
    setSemanas((prev) => {
      const copy = [...prev];
      copy[semIdx].dias[diaIdx].items[itemIdx].ejercicio = ex._id;
      copy[semIdx].dias[diaIdx].items[itemIdx].ejercicioObj = ex;
      return copy;
    });
    setPickOpen(false);
  };

  // ---------- Validación & Save ----------
  const flatItemsCount = useMemo(() => {
    return semanas.reduce(
      (acc, s) =>
        acc +
        (s.dias || []).reduce(
          (a2, d) => a2 + ((d.items || []).filter((it) => it.ejercicio).length || 0),
          0
        ),
      0
    );
  }, [semanas]);

  const validate = () => {
    if (!titulo.trim()) return "El título es obligatorio";
    if (!asesorId) return "Falta asesorid";
    if (!clienteId) return "Falta clienteId";
    if (flatItemsCount === 0) return "Añade al menos 1 ejercicio";
    return null;
  };

  const buildPayload = () => ({
    asesorId,
    clienteId,
    titulo: titulo.trim(),
    objetivo: objetivo.trim(),
    semanas: semanas.map((s, si) => ({
      numero: s.numero || si + 1,
      dias: (s.dias || []).map((d) => ({
        nombre: d.nombre?.trim() || "Día",
        items: (d.items || [])
          .filter((it) => it.ejercicio)
          .map((it, idx) => ({
            ejercicio: it.ejercicio,
            orden: idx,
            grupoId: it.grupoId || "",
            esquema: {
              series: Number(it.esquema?.series ?? 3),
              repsMin: Number(it.esquema?.repsMin ?? 8),
              repsMax: Number(it.esquema?.repsMax ?? 12),
              rir: it.esquema?.rir === "" ? undefined : Number(it.esquema?.rir ?? 1),
              descanso: it.esquema?.descanso === "" ? undefined : Number(it.esquema?.descanso ?? 90),
              notas: it.esquema?.notas || "",
            },
          })),
      })),
    })),
    activo,
  });

  const save = async () => {
    const err = validate();
    if (err) {
      setToast({ open: true, sev: "warning", msg: err });
      return;
    }
    try {
      setSaving(true);
      const payload = buildPayload();
      await API.put(`/entrenamientos/${id}`, payload);
      setToast({ open: true, sev: "success", msg: "Entrenamiento actualizado" });
      // volver a la vista o quedarse
      navigate(`/entrenamiento/${id}`);
    } catch (e) {
      console.error("PUT /entrenamientos/:id", e);
      const msg = e?.response?.data?.error || "No se pudo actualizar el entrenamiento";
      setToast({ open: true, sev: "error", msg });
    } finally {
      setSaving(false);
    }
  };

  // ---------- UI ----------
  return (
    <Box p={{ xs: 2, md: 4 }}>
      {/* HEADER */}
      <Paper
        elevation={0}
        sx={{
          p: { xs: 2, md: 3 },
          mb: 3,
          borderRadius: 3,
          border: "1px solid",
          borderColor: "divider",
          background: headerGradient,
        }}
      >
        <Stack direction={{ xs: "column", md: "row" }} justifyContent="space-between" spacing={2}>
          <Stack spacing={0.5}>
            <Stack direction="row" spacing={1} alignItems="center">
              <Avatar>
                <FitnessCenterIcon />
              </Avatar>
              <Typography variant="h5" fontWeight={800}>
                Editar entrenamiento
              </Typography>
            </Stack>
            <Typography variant="body2" color="text.secondary">
              Modifica semanas, días e incorpora ejercicios con sus parámetros.
            </Typography>
          </Stack>

          <Stack direction={{ xs: "column", sm: "row" }} spacing={1}>
            <Button variant="outlined" startIcon={<ArrowBackIcon />} onClick={() => navigate(-1)} sx={{ textTransform: "none" }}>
              Volver
            </Button>
            <Button variant="outlined" startIcon={<AddIcon />} onClick={addSemana} sx={{ textTransform: "none" }}>
              Añadir semana
            </Button>
            <Button variant="contained" startIcon={<SaveIcon />} onClick={save} disabled={saving} sx={{ textTransform: "none" }}>
              Guardar cambios
            </Button>
          </Stack>
        </Stack>
      </Paper>

      {/* FORM PRINCIPAL */}
      <Paper elevation={0} sx={{ p: 2, mb: 2, borderRadius: 3, border: "1px solid", borderColor: "divider" }}>
        {loading ? (
          <Grid container spacing={2}>
            {Array.from({ length: 5 }).map((_, i) => (
              <Grid item xs={12} md={i < 2 ? 6 : 12} key={i}>
                <Skeleton height={i < 2 ? 56 : 80} />
              </Grid>
            ))}
          </Grid>
        ) : (
          <Grid container spacing={2}>
            <Grid item xs={12} md={6}>
              <TextField label="Título *" value={titulo} onChange={(e) => setTitulo(e.target.value)} fullWidth />
            </Grid>
            <Grid item xs={12} md={6}>
              <TextField select label="Nivel (opcional)" value={nivel} onChange={(e) => setNivel(e.target.value)} fullWidth>
                <MenuItem value="">—</MenuItem>
                {NIVELES.map((n) => (
                  <MenuItem key={n} value={n}>
                    {n}
                  </MenuItem>
                ))}
              </TextField>
            </Grid>
            <Grid item xs={12}>
              <TextField label="Objetivo" value={objetivo} onChange={(e) => setObjetivo(e.target.value)} multiline minRows={2} fullWidth />
            </Grid>
            <Grid item xs={12} md={6}>
              <TextField
                label="clienteId *"
                value={clienteId || ""}
                onChange={(e) => setClienteId(e.target.value)}
                fullWidth
                InputProps={{ startAdornment: <InputAdornment position="start"><TodayIcon fontSize="small" /></InputAdornment> }}
              />
            </Grid>
            <Grid item xs={12} md={6}>
              <TextField
                label="asesorid *"
                value={asesorId || ""}
                disabled
                fullWidth
                InputProps={{ startAdornment: <InputAdornment position="start"><FlagIcon fontSize="small" /></InputAdornment> }}
              />
            </Grid>
          </Grid>
        )}
      </Paper>

      {/* SEMANAS / DÍAS / ITEMS */}
      {loading ? (
        <Grid container spacing={2}>
          {Array.from({ length: 2 }).map((_, i) => (
            <Grid item xs={12} key={i}>
              <Paper elevation={0} sx={{ p: 2, borderRadius: 3, border: "1px solid", borderColor: "divider" }}>
                <Skeleton width="30%" />
                <Divider sx={{ my: 2 }} />
                {Array.from({ length: 3 }).map((__, j) => (
                  <Skeleton key={j} height={36} sx={{ mb: 1 }} />
                ))}
              </Paper>
            </Grid>
          ))}
        </Grid>
      ) : (
        semanas.map((sem, semIdx) => (
          <Paper key={semIdx} elevation={0} sx={{ p: 2, mb: 2, borderRadius: 3, border: "1px solid", borderColor: "divider" }}>
            <Stack direction="row" justifyContent="space-between" alignItems="center" mb={1}>
              <Stack direction="row" spacing={1} alignItems="center">
                <Chip label={`Semana ${sem.numero || semIdx + 1}`} color="primary" variant="outlined" sx={{ borderRadius: 2 }} />
                <Typography variant="body2" color="text.secondary">{sem.dias?.length || 0} día(s)</Typography>
              </Stack>
              <Stack direction="row" spacing={1}>
                <Button size="small" startIcon={<PlaylistAddIcon />} onClick={() => addDia(semIdx)}>Añadir día</Button>
                <Button size="small" color="error" startIcon={<DeleteOutlineIcon />} onClick={() => removeSemana(semIdx)}>Eliminar semana</Button>
              </Stack>
            </Stack>

            <Divider sx={{ my: 1.5 }} />

            {(sem.dias || []).map((dia, diaIdx) => (
              <Box key={diaIdx} sx={{ mb: 2 }}>
                <Stack direction={{ xs: "column", sm: "row" }} justifyContent="space-between" alignItems={{ xs: "flex-start", sm: "center" }} spacing={1} mb={1}>
                  <Stack direction="row" spacing={1} alignItems="center">
                    <TextField
                      size="small"
                      label="Nombre del día"
                      value={dia.nombre}
                      onChange={(e) =>
                        setSemanas((prev) => {
                          const copy = [...prev];
                          copy[semIdx].dias[diaIdx].nombre = e.target.value;
                          return copy;
                        })
                      }
                    />
                    <Chip label={`${dia.items?.length || 0} ejercicio(s)`} size="small" variant="outlined" sx={{ borderRadius: 2 }} />
                  </Stack>
                  <Stack direction="row" spacing={1}>
                    <Button size="small" startIcon={<AddIcon />} onClick={() => addItem(semIdx, diaIdx)}>Añadir ejercicio</Button>
                    <Button size="small" startIcon={<ContentCopyIcon />} onClick={() => cloneDia(semIdx, diaIdx)}>Duplicar día</Button>
                    <Button size="small" color="error" startIcon={<DeleteOutlineIcon />} onClick={() => removeDia(semIdx, diaIdx)}>Eliminar día</Button>
                  </Stack>
                </Stack>

                <Paper variant="outlined" sx={{ borderRadius: 2, overflow: "hidden" }}>
                  <Table size="small">
                    <TableHead>
                      <TableRow sx={{ backgroundColor: "rgba(0,0,0,0.02)" }}>
                        <TableCell width={40} />
                        <TableCell sx={{ fontWeight: 700 }}>Ejercicio</TableCell>
                        <TableCell align="center">Series</TableCell>
                        <TableCell align="center">Reps</TableCell>
                        <TableCell align="center" title="Repeticiones en recámara">RIR</TableCell>
                        <TableCell align="center">Descanso (s)</TableCell>
                        <TableCell>Notas</TableCell>
                        <TableCell width={120}>Grupo</TableCell>
                        <TableCell align="right" width={130}>Acciones</TableCell>
                      </TableRow>
                    </TableHead>
                    <TableBody>
                      {(dia.items || []).map((it, itemIdx) => (
                        <TableRow key={itemIdx} hover>
                          <TableCell><DragIndicatorIcon fontSize="small" sx={{ color: "text.disabled" }} /></TableCell>
                          <TableCell>
                            <Stack direction="row" spacing={1} alignItems="center">
                              <Chip
                                size="small"
                                color={it.ejercicio ? "primary" : "default"}
                                label={
                                  it.ejercicioObj?.nombre
                                    ? it.ejercicioObj.nombre
                                    : it.ejercicio
                                    ? "Seleccionado"
                                    : "Elegir"
                                }
                                onClick={() => openPickerFor(semIdx, diaIdx, itemIdx)}
                                sx={{ borderRadius: 2, cursor: "pointer" }}
                              />
                              {it.ejercicioObj?.grupo && (
                                <Chip label={it.ejercicioObj.grupo} size="small" sx={{ borderRadius: 2 }} />
                              )}
                              {it.ejercicioObj?.equipo && (
                                <Chip label={it.ejercicioObj.equipo} size="small" variant="outlined" sx={{ borderRadius: 2 }} />
                              )}
                            </Stack>
                          </TableCell>
                          <TableCell align="center">
                            <TextField
                              size="small"
                              type="number"
                              value={it.esquema?.series ?? ""}
                              onChange={(e) => setItemField(semIdx, diaIdx, itemIdx, "esquema.series", e.target.value === "" ? "" : Math.max(1, Number(e.target.value)))}
                              inputProps={{ min: 1, style: { textAlign: "center", width: 70 } }}
                            />
                          </TableCell>
                          <TableCell align="center">
                            <Stack direction="row" spacing={1} alignItems="center" justifyContent="center">
                              <TextField
                                size="small"
                                type="number"
                                value={it.esquema?.repsMin ?? ""}
                                onChange={(e) => setItemField(semIdx, diaIdx, itemIdx, "esquema.repsMin", e.target.value === "" ? "" : Math.max(1, Number(e.target.value)))}
                                inputProps={{ min: 1, style: { textAlign: "center", width: 60 } }}
                              />
                              <Typography variant="body2">-</Typography>
                              <TextField
                                size="small"
                                type="number"
                                value={it.esquema?.repsMax ?? ""}
                                onChange={(e) => setItemField(semIdx, diaIdx, itemIdx, "esquema.repsMax", e.target.value === "" ? "" : Math.max(1, Number(e.target.value)))}
                                inputProps={{ min: 1, style: { textAlign: "center", width: 60 } }}
                              />
                            </Stack>
                          </TableCell>
                          <TableCell align="center">
                            <TextField
                              size="small"
                              type="number"
                              value={it.esquema?.rir ?? ""}
                              onChange={(e) => setItemField(semIdx, diaIdx, itemIdx, "esquema.rir", e.target.value === "" ? "" : Math.min(5, Math.max(0, Number(e.target.value))))}
                              inputProps={{ min: 0, max: 5, style: { textAlign: "center", width: 70 } }}
                            />
                          </TableCell>
                          <TableCell align="center">
                            <TextField
                              size="small"
                              type="number"
                              value={it.esquema?.descanso ?? ""}
                              onChange={(e) => setItemField(semIdx, diaIdx, itemIdx, "esquema.descanso", e.target.value === "" ? "" : Math.max(0, Number(e.target.value)))}
                              inputProps={{ min: 0, style: { textAlign: "center", width: 90 } }}
                            />
                          </TableCell>
                          <TableCell>
                            <TextField
                              size="small"
                              value={it.esquema?.notas ?? ""}
                              onChange={(e) => setItemField(semIdx, diaIdx, itemIdx, "esquema.notas", e.target.value)}
                              fullWidth
                            />
                          </TableCell>
                          <TableCell>
                            <TextField
                              size="small"
                              value={it.grupoId || ""}
                              onChange={(e) => setItemField(semIdx, diaIdx, itemIdx, "grupoId", e.target.value)}
                              placeholder="A / B / 1 ..."
                              helperText="Para superseries/circuitos"
                            />
                          </TableCell>
                          <TableCell align="right">
                            <Stack direction="row" spacing={0.5} justifyContent="flex-end">
                              <Tooltip title="Subir">
                                <span>
                                  <IconButton size="small" onClick={() => moveItem(semIdx, diaIdx, itemIdx, -1)} disabled={itemIdx === 0}>
                                    ↑
                                  </IconButton>
                                </span>
                              </Tooltip>
                              <Tooltip title="Bajar">
                                <span>
                                  <IconButton size="small" onClick={() => moveItem(semIdx, diaIdx, itemIdx, +1)} disabled={itemIdx === (dia.items?.length || 0) - 1}>
                                    ↓
                                  </IconButton>
                                </span>
                              </Tooltip>
                              <Tooltip title="Eliminar">
                                <IconButton size="small" color="error" onClick={() => removeItem(semIdx, diaIdx, itemIdx)}>
                                  <DeleteOutlineIcon />
                                </IconButton>
                              </Tooltip>
                            </Stack>
                          </TableCell>
                        </TableRow>
                      ))}
                      {(dia.items || []).length === 0 && (
                        <TableRow>
                          <TableCell colSpan={9}>
                            <Box p={2} textAlign="center" color="text.secondary">
                              No hay ejercicios. Pulsa <strong>Añadir ejercicio</strong>.
                            </Box>
                          </TableCell>
                        </TableRow>
                      )}
                    </TableBody>
                  </Table>
                </Paper>
              </Box>
            ))}
          </Paper>
        ))
      )}

      {/* PICKER DE EJERCICIOS */}
      <Dialog open={pickOpen} onClose={() => setPickOpen(false)} fullWidth maxWidth="md">
        <DialogTitle sx={{ fontWeight: 800, pr: 6 }}>
          Elegir ejercicio
          <IconButton onClick={() => setPickOpen(false)} sx={{ position: "absolute", right: 8, top: 8 }}>
            <CloseIcon />
          </IconButton>
        </DialogTitle>
        <DialogContent dividers>
          <Grid container spacing={1.5} alignItems="center" mb={1}>
            <Grid item xs={12} md={6}>
              <TextField
                fullWidth
                size="small"
                label="Buscar"
                value={searchQ}
                onChange={(e) => setSearchQ(e.target.value)}
                InputProps={{
                  startAdornment: <SearchIcon sx={{ mr: 1, color: "text.secondary" }} />,
                }}
              />
            </Grid>
            <Grid item xs={6} md={3}>
              <TextField select fullWidth size="small" label="Grupo" value={grupo} onChange={(e) => setGrupo(e.target.value)}>
                {GRUPOS.map((g) => (
                  <MenuItem key={g || "all"} value={g}>
                    {g || "Todos"}
                  </MenuItem>
                ))}
              </TextField>
            </Grid>
            <Grid item xs={6} md={3}>
              <TextField select fullWidth size="small" label="Equipo" value={equipo} onChange={(e) => setEquipo(e.target.value)}>
                {EQUIPOS.map((e) => (
                  <MenuItem key={e || "all"} value={e}>
                    {e || "Todos"}
                  </MenuItem>
                ))}
              </TextField>
            </Grid>
          </Grid>

          <Paper variant="outlined" sx={{ borderRadius: 2, overflow: "hidden" }}>
            <Table size="small">
              <TableHead>
                <TableRow sx={{ backgroundColor: "rgba(0,0,0,0.02)" }}>
                  <TableCell sx={{ fontWeight: 700 }}>Nombre</TableCell>
                  <TableCell>Grupo</TableCell>
                  <TableCell>Equipo</TableCell>
                  <TableCell>Nivel</TableCell>
                  <TableCell width={110} align="right">Seleccionar</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {exLoading &&
                  Array.from({ length: 5 }).map((_, i) => (
                    <TableRow key={i}>
                      <TableCell><Skeleton width="60%" /></TableCell>
                      <TableCell><Skeleton width="40%" /></TableCell>
                      <TableCell><Skeleton width="40%" /></TableCell>
                      <TableCell><Skeleton width="30%" /></TableCell>
                      <TableCell />
                    </TableRow>
                  ))}
                {!exLoading &&
                  exList.map((e) => (
                    <TableRow key={e._id} hover>
                      <TableCell sx={{ fontWeight: 600 }}>{e.nombre}</TableCell>
                      <TableCell>{e.grupo || "—"}</TableCell>
                      <TableCell>{e.equipo || "—"}</TableCell>
                      <TableCell>{e.nivel || "—"}</TableCell>
                      <TableCell align="right">
                        <Button size="small" variant="contained" onClick={() => pickEjercicio(e)}>
                          Elegir
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))}
                {!exLoading && exList.length === 0 && (
                  <TableRow>
                    <TableCell colSpan={5}>
                      <Box p={2} textAlign="center" color="text.secondary">
                        No hay resultados
                      </Box>
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </Paper>
        </DialogContent>
        <DialogActions sx={{ p: 2 }}>
          <Button onClick={() => setPickOpen(false)}>Cerrar</Button>
        </DialogActions>
      </Dialog>

      {/* TOAST */}
      <Snackbar
        open={toast.open}
        autoHideDuration={3000}
        onClose={() => setToast((t) => ({ ...t, open: false }))}
        anchorOrigin={{ vertical: "bottom", horizontal: "right" }}
      >
        <Alert severity={toast.sev} onClose={() => setToast((t) => ({ ...t, open: false }))} variant="filled" sx={{ width: "100%" }}>
          {toast.msg}
        </Alert>
      </Snackbar>
    </Box>
  );
}
