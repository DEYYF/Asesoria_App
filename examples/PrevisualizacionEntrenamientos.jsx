// src/pages/PrevisualizacionEntrenamientos.jsx
import { useEffect, useMemo, useState } from "react";
import {
  Box,
  Typography,
  Grid,
  Card,
  CardContent,
  CardActionArea,
  Chip,
  Button,
  Stack,
  Skeleton,
  CardActions,
  Tooltip,
} from "@mui/material";

import AddCircleOutlineIcon from "@mui/icons-material/AddCircleOutline";
import FitnessCenterIcon from "@mui/icons-material/FitnessCenter";
import EventIcon from "@mui/icons-material/Event";
import TimerIcon from "@mui/icons-material/Timer";
import FlagIcon from "@mui/icons-material/Flag";
import PlaylistAddCheckIcon from "@mui/icons-material/PlaylistAddCheck";
import MenuBookIcon from "@mui/icons-material/MenuBook";
import { useNavigate } from "react-router-dom";
import API from "../services/api";

const fmt = (n, d = 0) =>
  typeof n === "number" ? Number(n.toFixed(d)).toLocaleString() : n ?? "—";

export default function PrevisualizacionEntrenamientos({ clienteId }) {
  const [entrenamientos, setEntrenamientos] = useState([]);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        setLoading(true);
        // Si axios ya tiene baseURL="/api", esta ruta está bien.
        const res = await API.get(`/entrenamientos/cliente/${clienteId}`, {
          params: { limit: 100 },
        });
        if (mounted) setEntrenamientos(Array.isArray(res.data) ? res.data : []);
      } catch (e) {
        console.error("Error cargando entrenamientos", e);
        if (mounted) setEntrenamientos([]);
      } finally {
        if (mounted) setLoading(false);
      }
    })();
    return () => {
      mounted = false;
    };
  }, [clienteId]);

  const entrenamientosOrdenados = useMemo(
    () =>
      [...entrenamientos].sort(
        (a, b) =>
          new Date(b?.updatedAt || b?.createdAt || 0) -
          new Date(a?.updatedAt || a?.createdAt || 0)
      ),
    [entrenamientos]
  );

  return (
    <Box>
      <Stack
        direction={{ xs: "column", sm: "row" }}
        alignItems={{ xs: "stretch", sm: "center" }}
        justifyContent="space-between"
        spacing={1.5}
        mb={2}
      >
        <Typography variant="h6" fontWeight={800}>
          Entrenamientos asignados
        </Typography>

        <Tooltip title="Crear un nuevo entrenamiento para este cliente">
          <Button
            variant="contained"
            startIcon={<AddCircleOutlineIcon />}
            onClick={() => navigate(`/cliente/${clienteId}/crear-entrenamiento`)}
            sx={{ textTransform: "none", borderRadius: 2 }}
          >
            Crear nuevo entrenamiento
          </Button>
        </Tooltip>
      </Stack>

      {/* Estado de carga */}
      {loading && (
        <Grid container spacing={2}>
          {Array.from({ length: 3 }).map((_, i) => (
            <Grid item xs={12} md={6} lg={4} key={i}>
              <Card
                elevation={0}
                sx={{
                  borderRadius: 3,
                  border: "1px solid",
                  borderColor: "divider",
                }}
              >
                <Skeleton
                  variant="rectangular"
                  height={8}
                  sx={{ borderTopLeftRadius: 12, borderTopRightRadius: 12 }}
                />
                <CardContent>
                  <Skeleton width="60%" />
                  <Skeleton width="40%" />
                  <Stack direction="row" spacing={1} mt={1}>
                    <Skeleton variant="rounded" width={90} height={28} />
                    <Skeleton variant="rounded" width={110} height={28} />
                    <Skeleton variant="rounded" width={100} height={28} />
                  </Stack>
                </CardContent>
              </Card>
            </Grid>
          ))}
        </Grid>
      )}

      {/* Vacío */}
      {!loading && entrenamientosOrdenados.length === 0 && (
        <Box
          sx={{
            p: 3,
            borderRadius: 3,
            border: "1px dashed",
            borderColor: "divider",
            textAlign: "center",
            background:
              "linear-gradient(180deg, rgba(214,236,255,0.35) 0%, rgba(255,255,255,0.95) 70%)",
          }}
        >
          <Typography fontWeight={700} gutterBottom>
            Aún no hay entrenamientos
          </Typography>
          <Typography color="text.secondary" gutterBottom>
            Crea el primero para este cliente y visualiza aquí un resumen.
          </Typography>
          <Button
            variant="contained"
            startIcon={<AddCircleOutlineIcon />}
            onClick={() => navigate(`/cliente/${clienteId}/crear-entrenamiento`)}
            sx={{ textTransform: "none", borderRadius: 2, mt: 1 }}
          >
            Crear entrenamiento
          </Button>
        </Box>
      )}

      {/* Listado */}
      <Grid container spacing={2}>
        {entrenamientosOrdenados.map((ent) => {
          const fechaRaw = ent?.updatedAt || ent?.createdAt;
          const fecha = fechaRaw
            ? new Date(fechaRaw).toLocaleDateString()
            : "—";

          const nombre =
            ent?.titulo ||
            (fecha !== "—" ? `Entrenamiento del ${fecha}` : "Entrenamiento");

          const semanasCount =
            ent?.semanasCount ??
            (Array.isArray(ent?.semanas) ? ent.semanas.length : null);

          const diasCount =
            ent?.diasCount ??
            (Array.isArray(ent?.semanas)
              ? ent.semanas.reduce(
                  (acc, s) => acc + (Array.isArray(s?.dias) ? s.dias.length : 0),
                  0
                )
              : null);

          const ejerciciosCount =
            ent?.ejerciciosCount ??
            (Array.isArray(ent?.semanas)
              ? ent.semanas.reduce(
                  (acc, s) =>
                    acc +
                    (Array.isArray(s?.dias)
                      ? s.dias.reduce(
                          (acc2, d) =>
                            acc2 +
                            (Array.isArray(d?.items) ? d.items.length : 0),
                          0
                        )
                      : 0),
                  0
                )
              : null);

          const duracionMin =
            typeof ent?.duracionMin === "number" ? ent.duracionMin : null;

          const nivel = ent?.nivel || null;
          const objetivo = ent?.objetivo || null;

          return (
            <Grid item xs={12} md={6} lg={4} key={ent._id}>
              <Card
                elevation={0}
                sx={{
                  position: "relative",
                  borderRadius: 3,
                  border: "1px solid",
                  borderColor: "divider",
                  overflow: "hidden",
                  transition: "transform 0.2s ease",
                  "&:hover": { transform: "translateY(-2px)" },
                }}
              >
                {/* Barra superior */}
                <Box
                  sx={{
                    height: 8,
                    width: "100%",
                    background:
                      "linear-gradient(90deg, #80DEEA 0%, #B2EBF2 100%)",
                  }}
                />
                <CardActionArea
                  onClick={() => {
                    // ✅ Guardar clienteId en localStorage
                    localStorage.setItem("cliente", clienteId);
                    // ✅ Ir a la vista de detalle del entrenamiento
                    navigate(`/entrenamiento/${ent._id}`);
                  }}
                >
                  <CardContent>
                    <Stack
                      direction="row"
                      justifyContent="space-between"
                      alignItems="flex-start"
                    >
                      <Typography variant="h6" fontWeight={800}>
                        {nombre}
                      </Typography>
                    </Stack>

                    <Stack
                      direction="row"
                      spacing={1.25}
                      mt={1}
                      alignItems="center"
                      flexWrap="wrap"
                      useFlexGap
                    >
                      <Chip
                        icon={
                          <FitnessCenterIcon
                            sx={{ fontSize: 18 }}
                            color="primary"
                          />
                        }
                        label={
                          ejerciciosCount != null
                            ? `${fmt(ejerciciosCount)} ejercicio${
                                ejerciciosCount === 1 ? "" : "s"
                              }`
                            : "— ejercicios"
                        }
                        size="small"
                        sx={{ borderRadius: 2 }}
                      />

                      {diasCount != null && (
                        <Chip
                          icon={<PlaylistAddCheckIcon sx={{ fontSize: 18 }} />}
                          label={`${fmt(diasCount)} día${
                            diasCount === 1 ? "" : "s"
                          }`}
                          size="small"
                          variant="outlined"
                          sx={{ borderRadius: 2 }}
                        />
                      )}

                      {semanasCount != null && (
                        <Chip
                          icon={<FlagIcon sx={{ fontSize: 18 }} />}
                          label={`${fmt(semanasCount)} semana${
                            semanasCount === 1 ? "" : "s"
                          }`}
                          size="small"
                          variant="outlined"
                          sx={{ borderRadius: 2 }}
                        />
                      )}

                      {typeof duracionMin === "number" && (
                        <Chip
                          icon={<TimerIcon sx={{ fontSize: 18 }} />}
                          label={`${fmt(duracionMin)} min`}
                          size="small"
                          variant="outlined"
                          sx={{ borderRadius: 2 }}
                        />
                      )}

                      <Chip
                        icon={<EventIcon sx={{ fontSize: 18 }} />}
                        label={fecha}
                        size="small"
                        variant="outlined"
                        sx={{ borderRadius: 2 }}
                      />

                      {nivel && (
                        <Chip
                          icon={<FlagIcon sx={{ fontSize: 18 }} />}
                          label={String(nivel)}
                          size="small"
                          variant="outlined"
                          sx={{ borderRadius: 2 }}
                        />
                      )}
                    </Stack>

                    {objetivo && (
                      <Typography
                        variant="body2"
                        color="text.secondary"
                        sx={{ mt: 1.25 }}
                      >
                        {objetivo}
                      </Typography>
                    )}
                  </CardContent>
                </CardActionArea>
                <CardActions sx={{ px: 2, pb: 2 }}>
                    <Button
                        size="small"
                        variant="outlined"
                        color="secondary"
                        fullWidth
                        startIcon={<MenuBookIcon />}
                        onClick={() => navigate(`/entrenamiento/cuaderno/${ent._id}`)}
                    >
                        Registrar Sesión
                    </Button>
                </CardActions>
              </Card>
            </Grid>
          );
        })}
      </Grid>
    </Box>
  );
}
