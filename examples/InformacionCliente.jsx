import {
  Box,
  Typography,
  Stack,
  Divider,
  IconButton,
  Chip,
  Paper,
  Grid,
  Button,
  Card,
  CardContent,
} from "@mui/material";
import AddIcon from "@mui/icons-material/Add";
import RemoveIcon from "@mui/icons-material/Remove";
import API from "../../services/api";
import EditIcon from "@mui/icons-material/Edit";
import DeleteIcon from "@mui/icons-material/Delete";
import DialogEditarInformacion from "./DialogEditarInformacion";
import ConfirmDialog from "../ConfirmDialog";
import { useState } from "react";
import { useNavigate } from "react-router-dom";

const InformacionCliente = ({
  cliente,
  puedeRenovar,
  canAddProgress,
  onRenovar,
  onAbrirDialogProgreso,
  onAbrirCambiarTarifa,
  onAbrirGestionarExtras,
  onActualizar,
  onCounterUpdate, // New prop for counter updates
}) => {
  const [openEditarInformacion, setOpenEditarInformacion] = useState(false);
  const [openConfirmDialog, setOpenConfirmDialog] = useState(false);
  const navigate = useNavigate();

  // Get current month for display
  const currentMonth = new Date().toLocaleDateString('es-ES', { month: 'long', year: 'numeric' });


  return (
    <Paper sx={{ p: 3, mb: 3 }}>
      <Stack direction="row-reverse" spacing={1}>
        <IconButton
          onClick={() => setOpenEditarInformacion(true)}
          sx={{
            color: "#1976d2",
            backgroundColor: "#e3f2fd",
            "&:hover": {
              backgroundColor: "#bbdefb",
            },
          }}
          size="small"
        >
          <EditIcon />
        </IconButton>
      </Stack>

      <Divider sx={{ my: 2 }} />

      <Grid container spacing={2}>
        <Grid item xs={12} sm={6}>
          <Typography>
            <strong>Email:</strong> {cliente.email}
          </Typography>
          <Typography>
            <strong>Teléfono:</strong> {cliente.telefono}
          </Typography>
          <Typography>
            <strong>Sexo:</strong> {cliente.sexo}
          </Typography>
          <Typography>
            <strong>Altura:</strong> {cliente.altura} cm
          </Typography>
        </Grid>
        <Grid item xs={12} sm={6}>
          <Typography>
            <strong>Tarifa:</strong> {cliente.Tarifa} ({cliente.Tiempo_Tarifa})
          </Typography>
          <Typography>
            <strong>Vigencia:</strong>{" "}
            {new Date(cliente.fechaInicio).toLocaleDateString()} –{" "}
            {new Date(cliente.fechaFin).toLocaleDateString()}
          </Typography>
        </Grid>
        <Grid item xs={12}>
          <Typography>
            <strong>Objetivos:</strong>
          </Typography>
          <Box mt={1}>
            {cliente.objetivos.map((obj, i) => (
              <Chip key={i} label={obj} sx={{ mr: 1, mb: 1 }} />
            ))}
          </Box>
        </Grid>
        {cliente.extras && cliente.extras.length > 0 && (
          <Grid item xs={12}>
            <Typography>
              <strong>Extras:</strong>
            </Typography>
            <Box mt={1}>
              {cliente.extras.map((extra, i) => (
                <Chip 
                  key={i} 
                  label={typeof extra === 'object' ? extra.nombre : extra} 
                  color="secondary" 
                  sx={{ mr: 1, mb: 1 }} 
                />
              ))}
            </Box>
          </Grid>
        )}
        
        {/* Session Counter */}
        <Grid item xs={12}>
          <Card variant="outlined" sx={{ borderRadius: 2, bgcolor: "#f5f5f5" }}>
            <CardContent>
              <Typography variant="subtitle2" fontWeight={600} gutterBottom>
                Sesiones de Entrenamiento - {currentMonth}
              </Typography>
              <Stack direction="row" alignItems="center" spacing={2} sx={{ mt: 1 }}>
                <IconButton 
                  size="small" 
                  color="error"
                  onClick={() => onCounterUpdate?.('decrement')}
                  disabled={!cliente.sesionesCounter || cliente.sesionesCounter === 0}
                >
                  <RemoveIcon />
                </IconButton>
                <Chip 
                  label={`${cliente.sesionesCounter || 0} sesiones`} 
                  color="primary" 
                  sx={{ minWidth: 120, fontWeight: 600 }}
                />
                <IconButton 
                  size="small" 
                  color="success"
                  onClick={() => onCounterUpdate?.('increment')}
                >
                  <AddIcon />
                </IconButton>
              </Stack>
              <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
                Se reinicia automáticamente cada mes
              </Typography>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      <Stack direction="row" spacing={2} mt={3} flexWrap="wrap" useFlexGap>
        {puedeRenovar && (
          <Button
            variant="contained"
            onClick={onRenovar}
            sx={{
              backgroundColor: "#0288d1",
              "&:hover": { backgroundColor: "#0277bd" },
              borderRadius: "20px",
              textTransform: "none",
            }}
          >
            Renovar tarifa
          </Button>
        )}
        {canAddProgress && (
          <Button
            variant="contained"
            onClick={onAbrirDialogProgreso}
            sx={{
              backgroundColor: "#1976d2",
              "&:hover": { backgroundColor: "#1565c0" },
              borderRadius: "20px",
              textTransform: "none",
            }}
          >
            Añadir progreso
          </Button>
        )}
        <Button
          variant="contained"
          onClick={onAbrirCambiarTarifa}
          sx={{
            backgroundColor: "#2e7d32",
            "&:hover": { backgroundColor: "#1b5e20" },
            borderRadius: "20px",
            textTransform: "none",
          }}
        >
          Cambiar tarifa
        </Button>
        <Button
          variant="contained"
          onClick={onAbrirGestionarExtras}
          sx={{
            backgroundColor: "#f57c00",
            "&:hover": { backgroundColor: "#e65100" },
            borderRadius: "20px",
            textTransform: "none",
          }}
        >
          Gestionar Extras
        </Button>
      </Stack>

      <DialogEditarInformacion
        open={openEditarInformacion}
        onClose={() => setOpenEditarInformacion(false)}
        cliente={cliente}
        onActualizar={onActualizar}
      />

    </Paper>
  );
};

export default InformacionCliente;
