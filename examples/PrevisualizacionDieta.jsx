import { useEffect, useState, useMemo } from "react";
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
  Tooltip,
} from "@mui/material";
import AddCircleOutlineIcon from "@mui/icons-material/AddCircleOutline";
import LocalFireDepartmentIcon from "@mui/icons-material/LocalFireDepartment";
import EventIcon from "@mui/icons-material/Event";
import FlagIcon from "@mui/icons-material/Flag";
import { useNavigate } from "react-router-dom";
import API from "../services/api";

const fmt = (n, d = 0) =>
  typeof n === "number" ? Number(n.toFixed(d)).toLocaleString() : n ?? "-";

const PrevisualizacionDieta = ({ clienteId }) => {
  const [dietas, setDietas] = useState([]);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        setLoading(true);
        // NUEVO: usamos /dietas?clienteId=...&isCurrent=true (backend nuevo)
        const res = await API.get(`/dietas`, {
          params: { clienteId, isCurrent: "true" },
        });
        if (mounted) setDietas(Array.isArray(res.data) ? res.data : []);
      } catch (e) {
        console.error("Error cargando dietas", e);
        if (mounted) setDietas([]);
      } finally {
        if (mounted) setLoading(false);
      }
    })();
    return () => {
      mounted = false;
    };
  }, [clienteId]);

  // NUEVO: ordena por createdAt (antes: fechaCreacion)
  const dietasOrdenadas = useMemo(
    () =>
      [...dietas].sort(
        (a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0)
      ),
    [dietas]
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
          Dietas asignadas
        </Typography>

        <Tooltip title="Crear una nueva dieta para este cliente">
          <Button
            variant="contained"
            startIcon={<AddCircleOutlineIcon />}
            onClick={() => navigate(`/cliente/${clienteId}/crear-dieta`)}
            sx={{ textTransform: "none", borderRadius: 2 }}
          >
            Crear nueva dieta
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
                    <Skeleton variant="rounded" width={80} height={28} />
                    <Skeleton variant="rounded" width={100} height={28} />
                    <Skeleton variant="rounded" width={90} height={28} />
                  </Stack>
                </CardContent>
              </Card>
            </Grid>
          ))}
        </Grid>
      )}

      {/* Vacío */}
      {!loading && dietasOrdenadas.length === 0 && (
        <Box
          sx={{
            p: 3,
            borderRadius: 3,
            border: "1px dashed",
            borderColor: "divider",
            textAlign: "center",
            background:
              "linear-gradient(180deg, rgba(255,244,214,0.35) 0%, rgba(255,255,255,0.95) 70%)",
          }}
        >
          <Typography fontWeight={700} gutterBottom>
            Aún no hay dietas
          </Typography>
          <Typography color="text.secondary" gutterBottom>
            Crea la primera dieta para este cliente y visualiza aquí un resumen.
          </Typography>
          <Button
            variant="contained"
            startIcon={<AddCircleOutlineIcon />}
            onClick={() => navigate(`/cliente/${clienteId}/crear-dieta`)}
            sx={{ textTransform: "none", borderRadius: 2, mt: 1 }}
          >
            Crear dieta
          </Button>
        </Box>
      )}

      {/* Listado */}
      <Grid container spacing={2}>
        {dietasOrdenadas.map((dieta) => {
          const fechaStr = new Date(dieta.createdAt || dieta.fechaCreacion || Date.now()).toLocaleDateString();

          // NUEVO: kcal desde macros.kcal (fallback a caloriasTotales si existiera)
          const kcal =
            (dieta?.macros && typeof dieta.macros.kcal === "number"
              ? dieta.macros.kcal
              : dieta?.caloriasTotales) || 0;

          // NUEVO: objetivo (string) como chip; fallback a objetivos (array) si existiera
          const objetivo = dieta?.objetivo;
          const objetivosArr = Array.isArray(dieta?.objetivos) ? dieta.objetivos : null;

          return (
            <Grid item xs={12} md={6} lg={4} key={dieta._id}>
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
                {/* Barra superior cálida */}
                <Box
                  sx={{
                    height: 8,
                    width: "100%",
                    background:
                      "linear-gradient(90deg, #FFD180 0%, #FFF59D 100%)",
                  }}
                />
                <CardActionArea
                  onClick={() => {
                    localStorage.setItem("cliente", clienteId);
                    navigate(`/dieta/${dieta._id}`);
                  }}
                >
                  <CardContent>
                    <Stack
                      direction="row"
                      justifyContent="space-between"
                      alignItems="flex-start"
                    >
                      <Typography variant="h6" fontWeight={800}>
                        Dieta del {fechaStr}
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
                          <LocalFireDepartmentIcon
                            sx={{ fontSize: 18 }}
                            color="error"
                          />
                        }
                        label={`${fmt(kcal, 0)} kcal`}
                        size="small"
                        sx={{ borderRadius: 2 }}
                      />
                      <Chip
                        icon={<EventIcon sx={{ fontSize: 18 }} />}
                        label={fechaStr}
                        size="small"
                        variant="outlined"
                        sx={{ borderRadius: 2 }}
                      />
                      {/* NUEVO: chip de objetivo (string) si existe */}
                      {objetivo && (
                        <Chip
                          icon={<FlagIcon sx={{ fontSize: 18 }} />}
                          label={objetivo}
                          size="small"
                          variant="outlined"
                          sx={{ borderRadius: 2 }}
                        />
                      )}
                    </Stack>

                    {/* Fallback: si aún recibes objetivos (array) lo mostramos como antes */}
                    {objetivosArr && objetivosArr.length > 0 && (
                      <Stack
                        direction="row"
                        spacing={1}
                        mt={1.25}
                        flexWrap="wrap"
                        useFlexGap
                      >
                        {objetivosArr.slice(0, 3).map((o, i) => (
                          <Chip
                            key={i}
                            icon={<FlagIcon sx={{ fontSize: 18 }} />}
                            label={o}
                            size="small"
                            variant="outlined"
                            sx={{ borderRadius: 2 }}
                          />
                        ))}
                        {objetivosArr.length > 3 && (
                          <Chip
                            label={`+${objetivosArr.length - 3}`}
                            size="small"
                            variant="outlined"
                            sx={{ borderRadius: 2 }}
                          />
                        )}
                      </Stack>
                    )}
                  </CardContent>
                </CardActionArea>
              </Card>
            </Grid>
          );
        })}
      </Grid>
    </Box>
  );
};

export default PrevisualizacionDieta;
