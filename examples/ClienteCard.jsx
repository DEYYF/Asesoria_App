import { useEffect, useMemo, useState, useCallback, memo } from "react";
import {
  Box,
  Typography,
  Avatar,
  Stack,
  Chip,
  Button,
  Paper,
  Tooltip,
  Badge,
  IconButton,
  Menu,
  MenuItem,
  ListItemIcon,
  ListItemText,
  Divider,
} from "@mui/material";
import EmailIcon from "@mui/icons-material/Email";
import LocalPhoneIcon from "@mui/icons-material/LocalPhone";
import CalendarIcon from "@mui/icons-material/CalendarToday";
import EventIcon from "@mui/icons-material/Event";
import PersonIcon from "@mui/icons-material/Person";
import MoreVertIcon from "@mui/icons-material/MoreVert";
import RestoreFromTrashIcon from "@mui/icons-material/RestoreFromTrash";
import ArchiveIcon from "@mui/icons-material/Archive";
import DeleteOutlineIcon from "@mui/icons-material/DeleteOutline";
import API from "../services/api";
import DialogCorreo from "./DialogCorreo";
import DialogCita from "./DialogCita";
import {useNavigate} from "react-router-dom";

const initials = (name = "") =>
  name
    .split(" ")
    .map((p) => p[0])
    .filter(Boolean)
    .slice(0, 2)
    .join("")
    .toUpperCase();

const prettyDate = (d) => (d ? new Date(d).toLocaleDateString() : "-");

const estadoColor = (estado) => {
  switch (estado) {
    case "Activo":
      return "success";
    case "En Proceso":
      return "warning";
    case "Inactivo":
      return "error";
    default:
      return "default";
  }
};

// --- normaliza objetivos pase lo que pase (array, string, null)
const parseObjetivos = (val) => {
  if (Array.isArray(val)) {
    return val.map((s) => String(s).trim()).filter(Boolean);
  }
  if (typeof val === "string") {
    return val
      .split(/[;,·|\-]/g)
      .map((s) => s.trim())
      .filter(Boolean);
  }
  return [];
};

function ClienteCard({ cliente, onDelete, onToggleStatus }) {
  const [estado, setEstado] = useState("Cargando…");
  const [ultimaDietaDias, setUltimaDietaDias] = useState(null);
  const [openEmail, setOpenEmail] = useState(false);
  const [openCita, setOpenCita] = useState(false);

  const navigate = useNavigate();

  const objetivos = useMemo(() => parseObjetivos(cliente?.objetivos), [cliente?.objetivos]);

  // Handlers estables
  const handleOpenEmail = useCallback(() => setOpenEmail(true), []);
  const handleCloseEmail = useCallback(() => setOpenEmail(false), []);
  const handleOpenCita = useCallback(() => setOpenCita(true), []);
  const handleCloseCita = useCallback(() => setOpenCita(false), []);
  const handlePerfil = useCallback(
    () => (navigate(`/clientes/${cliente._id}`)),
    [cliente._id]
  );

  useEffect(() => {
    const calcular = async () => {
      const hoy = new Date();
      const venc = cliente.fechaFin ? new Date(cliente.fechaFin) : null;

      if (venc && venc < hoy) {
        setEstado("Inactivo");
        return;
      }

      try {
        const dietas = await API.get(`/dietas/cliente/${cliente._id}`);
        const tieneDieta = (dietas.data || []).length > 0;

        if (cliente.Tarifa !== "" && venc && venc > hoy && !tieneDieta) {
          setEstado("En Proceso");
          return;
        }
        if (
          (cliente.Tarifa === "Dieta" && tieneDieta) ||
          cliente.Tarifa === "Entrenamiento" ||
          (cliente.Tarifa === "Dieta Y Entrenamiento" && tieneDieta)
        ) {
          setEstado("Activo");
        } else {
          setEstado("Desconocido");
        }
      } catch {
        setEstado("Desconocido");
      }
    };

    const ultimaDieta = async () => {
      try {
        const res = await API.get(`/dietas/cliente/${cliente._id}/ultima`);
        if (res?.data?.createdAt || res?.data?.fechaCreacion) {
          const fechaUlt = new Date(res.data.createdAt || res.data.fechaCreacion);
          const hoy = new Date();
          // Set both dates to midnight to get accurate day difference
          fechaUlt.setHours(0, 0, 0, 0);
          hoy.setHours(0, 0, 0, 0);
          const dias = Math.floor((hoy - fechaUlt) / (1000 * 60 * 60 * 24));
          setUltimaDietaDias(dias);
        } else {
          setUltimaDietaDias(null);
        }
      } catch {
        setUltimaDietaDias(null);
      }
    };

    calcular();
    ultimaDieta();
  }, [cliente]);

  const telHref = useMemo(
    () => (cliente.telefono ? `tel:${String(cliente.telefono).replace(/\s+/g, "")}` : null),
    [cliente.telefono]
  );

  return (
    <>
      <Paper
        variant="outlined"
        sx={{
          p: 2,
          borderRadius: 3,
          borderColor: "divider",
          transition: "transform .15s ease, box-shadow .2s ease",
          "&:hover": { transform: "translateY(-2px)", boxShadow: 3 },
        }}
      >
        <Stack
          direction={{ xs: "column", md: "row" }}
          spacing={2}
          alignItems={{ xs: "flex-start", md: "center" }}
          justifyContent="space-between"
        >
          {/* Columna izquierda */}
          <Stack direction="row" spacing={2} alignItems="center" sx={{ flex: 1, minWidth: 0 }}>
            <Badge
              overlap="circular"
              anchorOrigin={{ vertical: "bottom", horizontal: "right" }}
              badgeContent={
                <Box
                  sx={{
                    width: 10,
                    height: 10,
                    borderRadius: "50%",
                    bgcolor:
                      cliente.fechaFin && new Date(cliente.fechaFin) >= new Date()
                        ? "success.main"
                        : "warning.main",
                    border: "2px solid white",
                  }}
                />
              }
            >
              <Avatar sx={{ width: 48, height: 48, bgcolor: "primary.light" }}>
                {initials(cliente.nombre)}
              </Avatar>
            </Badge>

            <Box sx={{ flex: 1, minWidth: 0 }}>
              <Typography variant="h6" noWrap title={cliente.nombre}>
                {cliente.nombre}
              </Typography>

              {/* Email + Teléfono */}
              <Stack
                direction="row"
                spacing={1.5}
                alignItems="center"
                sx={{ color: "text.secondary", mt: 0.5, minWidth: 0 }}
              >
                {cliente.email && (
                  <Typography
                    variant="body2"
                    noWrap
                    title={cliente.email}
                    sx={{ maxWidth: { xs: "100%", md: 260 } }}
                  >
                    {cliente.email}
                  </Typography>
                )}
                {cliente.telefono && (
                  <Stack direction="row" spacing={0.5} alignItems="center">
                    <LocalPhoneIcon fontSize="small" />
                    <Typography variant="body2">{cliente.telefono}</Typography>
                  </Stack>
                )}
              </Stack>

              {/* Objetivos */}
              <Stack
                direction="row"
                spacing={1}
                mt={1}
                flexWrap="wrap"
                useFlexGap
                sx={{ rowGap: 0.75 }}
              >
                {objetivos.slice(0, 3).map((o, i) => (
                  <Chip key={`${o}-${i}`} size="small" label={o} sx={{ borderRadius: 2 }} />
                ))}
                {objetivos.length > 3 && (
                  <Chip
                    size="small"
                    variant="outlined"
                    label={`+${objetivos.length - 3}`}
                    sx={{ borderRadius: 2 }}
                  />
                )}
              </Stack>
            </Box>
          </Stack>

          {/* Columna centro */}
          <Stack spacing={0.5} sx={{ minWidth: { md: 260 }, width: { xs: "100%", md: "auto" } }}>
            <Chip
              label={estado}
              color={estadoColor(estado)}
              size="small"
              sx={{ alignSelf: { md: "flex-start" }, borderRadius: 2 }}
            />
            <Stack direction="row" spacing={0.5} alignItems="center">
              <EventIcon fontSize="small" color="action" />
              <Typography variant="body2" color="text.secondary" noWrap>
                Última dieta:{" "}
                {ultimaDietaDias !== null
                  ? `hace ${ultimaDietaDias} día${ultimaDietaDias === 1 ? "" : "s"}`
                  : "No disponible"}
              </Typography>
            </Stack>
            <Typography variant="body2" color="text.secondary">
              {prettyDate(cliente.fechaInicio)} → {prettyDate(cliente.fechaFin)}
            </Typography>
          </Stack>

          {/* Columna derecha: acciones */}
          <Stack
            direction="row"
            spacing={1}
            useFlexGap
            flexWrap="wrap"
            justifyContent={{ xs: "flex-start", md: "flex-end" }}
            sx={{ minWidth: { md: 260 } }}
          >
            <Tooltip title={cliente.telefono ? `Llamar a ${cliente.telefono}` : "Sin teléfono"}>
              <span>
                <Button
                  size="small"
                  variant="outlined"
                  startIcon={<LocalPhoneIcon />}
                  href={telHref || undefined}
                  disabled={!telHref}
                  sx={{ borderRadius: 2 }}
                >
                  Llamar
                </Button>
              </span>
            </Tooltip>

            <Tooltip title="Añadir cita">
              <span>
                <Button
                  size="small"
                  variant="outlined"
                  startIcon={<CalendarIcon />}
                  onClick={handleOpenCita}
                  sx={{ borderRadius: 2 }}
                >
                  Añadir cita
                </Button>
              </span>
            </Tooltip>

            <Tooltip title="Ver perfil">
              <Button
                size="small"
                variant="contained"
                startIcon={<PersonIcon />}
                onClick={handlePerfil}
                sx={{ borderRadius: 2 }}
              >
                Perfil
              </Button>
            </Tooltip>

             {/* More Actions Menu */}
             <ActionMenu cliente={cliente} onDelete={onDelete} onToggleStatus={onToggleStatus} />
          </Stack>
        </Stack>
      </Paper>

      <DialogCorreo abierto={openEmail} onClose={handleCloseEmail} cliente={cliente} />
      <DialogCita abierto={openCita} onClose={handleCloseCita} cliente={cliente} />
    </>
  );
}

// Subcomponente para el menú de acciones para limpieza
function ActionMenu({ cliente, onDelete, onToggleStatus }) {
  const [anchorEl, setAnchorEl] = useState(null);
  const open = Boolean(anchorEl);
  const isBaja = cliente.estado === "Baja";

  const handleClick = (event) => setAnchorEl(event.currentTarget);
  const handleClose = () => setAnchorEl(null);

  const handleStatus = () => {
    handleClose();
    if (onToggleStatus) onToggleStatus(cliente);
  };

  const handleDelete = () => {
    handleClose();
    if (onDelete) onDelete(); // ClienteCard ya recibe onDelete que llama a requestDelete en padre
  };

  return (
    <>
      <IconButton size="small" onClick={handleClick}>
         <MoreVertIcon />
      </IconButton>
      <Menu
        anchorEl={anchorEl}
        open={open}
        onClose={handleClose}
        transformOrigin={{ horizontal: 'right', vertical: 'top' }}
        anchorOrigin={{ horizontal: 'right', vertical: 'bottom' }}
      >
        <MenuItem onClick={handleStatus}>
           <ListItemIcon>
              {isBaja ? <RestoreFromTrashIcon fontSize="small" /> : <ArchiveIcon fontSize="small" />}
           </ListItemIcon>
           <ListItemText>{isBaja ? "Reactivar Cliente" : "Dar de baja"}</ListItemText>
        </MenuItem>
        <Divider />
        <MenuItem onClick={handleDelete} sx={{ color: 'error.main' }}>
            <ListItemIcon>
              <DeleteOutlineIcon fontSize="small" color="error" />
            </ListItemIcon>
            <ListItemText>Eliminar</ListItemText>
        </MenuItem>
      </Menu>
    </>
  );
}

// Comparación fina para evitar renders innecesarios
function areEqual(prev, next) {
  const a = prev.cliente ?? {};
  const b = next.cliente ?? {};
  if (a === b) return true;
  if (a._id !== b._id) return false;
  if (a.nombre !== b.nombre) return false;
  if (a.Tarifa !== b.Tarifa) return false;
  if (a.email !== b.email) return false;
  if (a.telefono !== b.telefono) return false;
  if (a.fechaFin !== b.fechaFin) return false;
  if (a.fechaInicio !== b.fechaInicio) return false;
  if (a.objetivos !== b.objetivos) return false;
  if (a.updatedAt !== b.updatedAt) return false;
  return true;
}

export default memo(ClienteCard, areEqual);
