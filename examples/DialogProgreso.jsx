import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  TextField,
  Grid,
  Alert,
} from "@mui/material";
import { useState } from "react";
import API from "../../services/api";

const musculosBase = [
  "Brazo",
  "Espalda",
  "Pecho",
  "Hombro", // New
  "Trapecio", // New
  "Antebrazo",
  "Glúteo", // New
  "Cuádriceps", // New
  "Femoral",    // New
  "Gemelo",
  "CINTURA ANCHA",
  "CINTURA ESTRECHA",
];

const DialogProgreso = ({ open, onClose, clienteId, onProgresoAñadido, asesorId }) => {
  const [peso, setPeso] = useState("");
  const [grasaCorporal, setGrasaCorporal] = useState("");
  const [musculoMedidas, setMusculoMedidas] = useState(
    musculosBase.map((m) => ({ nombre: m, medida: "" }))
  );
  const [error, setError] = useState("");

  const handleChangeMedida = (index, value) => {
    // Validation: prevent negative
    if (value < 0) return;
    
    const actualizado = [...musculoMedidas];
    actualizado[index].medida = value;
    setMusculoMedidas(actualizado);
  };

  const handleGuardar = async () => {
    setError("");

    // Validation: Check for empty essential info if needed, or just sanitize
    if (!peso && !grasaCorporal && musculoMedidas.every(m => !m.medida)) {
        setError("Debes ingresar al menos un dato (peso, grasa o medidas).");
        return;
    }
    
    if (peso && parseFloat(peso) <= 0) {
        setError("El peso debe ser mayor a 0.");
        return;
    }

    try {
      await API.put(`/clientes/${clienteId}/historial`, {
        fecha: new Date(),
        peso,
        grasaCorporal,
        musculo: musculoMedidas
            .filter(m => m.medida !== "") // Filter out empty strings
            .map((m) => ({
              nombre: m.nombre,
              medida: parseFloat(m.medida),
            })),
      });
      onProgresoAñadido(); // para refrescar el cliente
      onClose();
      // Reset fields
      setPeso("");
      setGrasaCorporal("");
      setMusculoMedidas(musculosBase.map((m) => ({ nombre: m, medida: "" })));
    } catch (error) {
      if (error.response) {
        console.error("Error al añadir progreso:", error.response.data);
        setError("Error al guardar: " + (error.response.data.error || "Datos inválidos"));
      } else {
        console.error("Error al añadir progreso:", error.message);
        setError("Error de conexión");
      }
    }
  };

  return (
    <Dialog open={open} onClose={onClose} maxWidth="md" fullWidth>
      <DialogTitle>Añadir Progreso</DialogTitle>
      <DialogContent dividers>
        {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
        
        <Grid container spacing={2}>
          <Grid item xs={6} sm={4}>
            <TextField
              label="Peso (kg)"
              fullWidth
              type="number"
              value={peso}
              onChange={(e) => {
                  const val = e.target.value;
                  if (val >= 0) setPeso(val);
              }}
            />
          </Grid>
          <Grid item xs={6} sm={4}>
            <TextField
              label="Grasa corporal (%)"
              fullWidth
              type="number"
              value={grasaCorporal}
              onChange={(e) => {
                  const val = e.target.value;
                  if (val >= 0) setGrasaCorporal(val);
              }}
            />
          </Grid>
          
          <Grid item xs={12}>
             <Button 
                variant="text" 
                size="small" 
                onClick={() => setMusculoMedidas(musculosBase.map(m => ({...m, medida: ""} )))}
             >
                Limpiar medidas
             </Button>
          </Grid>

          {musculoMedidas.map((musculo, i) => (
            <Grid item xs={6} sm={3} key={musculo.nombre}>
              <TextField
                label={musculo.nombre}
                fullWidth
                type="number"
                size="small"
                value={musculo.medida}
                onChange={(e) => handleChangeMedida(i, e.target.value)}
              />
            </Grid>
          ))}
        </Grid>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancelar</Button>
        <Button variant="contained" onClick={handleGuardar}>
          Guardar
        </Button>
      </DialogActions>
    </Dialog>
  );
};

export default DialogProgreso;
