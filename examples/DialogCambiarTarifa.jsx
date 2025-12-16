import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
} from "@mui/material";
import { useState, useEffect } from "react";
import API from "../../services/api";

const DialogCambiarTarifa = ({ open, onClose, clienteId, onTarifaActualizada, asesorId}) => {
  const [nuevaTarifa, setNuevaTarifa] = useState("");
  const [tarifasDisponibles, setTarifasDisponibles] = useState([]);

  useEffect(() => {
    if (open) {
      API.get("/tarifas")
        .then((res) => setTarifasDisponibles(res.data))
        .catch((err) => console.error("Error cargando tarifas", err));
    }
  }, [open]);

  const handleGuardar = async () => {
    try {
      await API.put(`/clientes/${clienteId}/tarifa`, {
        Tarifa: nuevaTarifa,
        // No enviamos Tiempo_Tarifa, se calcula en el backend desde duracionDias
     });

      onTarifaActualizada?.();
      onClose();
    } catch (error) {
      console.error("Error al cambiar la tarifa:", error);
    }
  };

  return (
    <Dialog open={open} onClose={onClose} fullWidth>
      <DialogTitle>Actualizar tarifa del cliente</DialogTitle>
      <DialogContent>
        <FormControl fullWidth margin="normal">
          <InputLabel>Tarifa</InputLabel>
          <Select
            value={nuevaTarifa}
            onChange={(e) => setNuevaTarifa(e.target.value)}
            label="Tarifa"
          >
            {tarifasDisponibles.map((t) => (
              <MenuItem key={t._id} value={t.nombre}>
                {t.nombre} - {t.duracionDias} días (${t.precio})
              </MenuItem>
            ))}
          </Select>
        </FormControl>
      </DialogContent>

      <DialogActions>
        <Button onClick={onClose}>Cancelar</Button>
        <Button variant="contained" onClick={handleGuardar} disabled={!nuevaTarifa}>
          Guardar cambios
        </Button>
      </DialogActions>
    </Dialog>
  );
};

export default DialogCambiarTarifa;