import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  FormGroup,
  FormControlLabel,
  Checkbox,
  Typography,
  Box,
  CircularProgress,
} from "@mui/material";
import { useState, useEffect } from "react";
import API from "../../services/api";

const DialogGestionarExtras = ({ open, onClose, cliente, onActualizar }) => {
  const [extrasDisponibles, setExtrasDisponibles] = useState([]);
  const [extrasSeleccionados, setExtrasSeleccionados] = useState([]);
  const [presupuestoActivo, setPresupuestoActivo] = useState(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (open && cliente?._id) {
      setLoading(true);
      
      // Cargar extras disponibles
      API.get("/extras")
        .then((res) => setExtrasDisponibles(res.data))
        .catch((err) => console.error("Error cargando extras", err));

      // Cargar el último presupuesto del cliente
      API.get(`/presupuestos?clienteId=${cliente._id}`)
        .then((res) => {
          if (res.data && res.data.length > 0) {
            const ultimoPresupuesto = res.data[0]; // Ya viene ordenado por createdAt desc
            setPresupuestoActivo(ultimoPresupuesto);
            
            // Extraer IDs de extras del presupuesto
            const extrasIds = ultimoPresupuesto.extras.map(e => 
              typeof e.extraId === 'object' ? e.extraId._id : e.extraId
            );
            setExtrasSeleccionados(extrasIds);
          } else {
            setPresupuestoActivo(null);
            setExtrasSeleccionados([]);
          }
        })
        .catch((err) => {
          console.error("Error cargando presupuesto", err);
          setPresupuestoActivo(null);
          setExtrasSeleccionados([]);
        })
        .finally(() => setLoading(false));
    }
  }, [open, cliente]);

  const handleToggle = (id) => {
    setExtrasSeleccionados((prev) => {
      if (prev.includes(id)) {
        return prev.filter((x) => x !== id);
      } else {
        return [...prev, id];
      }
    });
  };

  const handleGuardar = async () => {
    try {
      if (!presupuestoActivo) {
        console.error("No hay presupuesto activo para actualizar");
        return;
      }

      // Actualizar el presupuesto existente con los nuevos extras
      await API.put(`/presupuestos/${presupuestoActivo._id}/extras`, {
        extras: extrasSeleccionados,
      });
      
      onActualizar?.();
      onClose();
    } catch (error) {
      console.error("Error guardando extras:", error);
    }
  };

  return (
    <Dialog open={open} onClose={onClose} fullWidth maxWidth="sm">
      <DialogTitle>Gestionar Extras</DialogTitle>
      <DialogContent>
        {loading ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', py: 3 }}>
            <CircularProgress />
          </Box>
        ) : !presupuestoActivo ? (
          <Typography color="error" sx={{ mt: 2 }}>
            No hay presupuesto activo para este cliente.
          </Typography>
        ) : (
          <Box sx={{ mt: 2 }}>
            {extrasDisponibles.length === 0 ? (
              <Typography color="text.secondary">No hay extras disponibles.</Typography>
            ) : (
              <FormGroup>
                {extrasDisponibles.map((extra) => (
                  <FormControlLabel
                    key={extra._id}
                    control={
                      <Checkbox
                        checked={extrasSeleccionados.includes(extra._id)}
                        onChange={() => handleToggle(extra._id)}
                      />
                    }
                    label={`${extra.nombre} (+${extra.precio}€/mes)`}
                  />
                ))}
              </FormGroup>
            )}
          </Box>
        )}
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancelar</Button>
        <Button 
          variant="contained" 
          onClick={handleGuardar}
          disabled={!presupuestoActivo || loading}
        >
          Guardar Cambios
        </Button>
      </DialogActions>
    </Dialog>
  );
};

export default DialogGestionarExtras;
