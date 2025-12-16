import {
  useEffect,
  useState,
  useMemo,
  useRef,
  useCallback,
  Suspense,
  lazy,
  startTransition,
} from "react";
import { useParams, Link as RouterLink, useNavigate } from "react-router-dom";
import {
  Box,
  Typography,
  Paper,
  Tabs,
  Tab,
  Divider,
  Stack,
  Chip,
  Breadcrumbs,
  Link,
  Button,
  Skeleton,
  Alert,
} from "@mui/material";
import DeleteOutlineIcon from "@mui/icons-material/DeleteOutline";
import API from "../services/api";
import ConfirmDialog from "../components/ConfirmDialog";
import { useToast } from "../utils/toast";
import { useSnackbar } from "notistack";

/** Carga diferida de piezas pesadas */
const DialogProgreso = lazy(() => import("../components/Perfil/DialogProgreso"));
const GraficaPeso = lazy(() => import("../components/Perfil/GraficaPeso"));
const GraficaGrasaCorporal = lazy(() => import("../components/Perfil/GraficaGrasaCorporal"));
const GraficaMuscular = lazy(() => import("../components/Perfil/GraficaMuscular"));
const DialogCambiarTarifa = lazy(() => import("../components/Perfil/DialogCambiarTarifa"));
const DialogGestionarExtras = lazy(() => import("../components/Perfil/DialogGestionarExtras"));
const InformacionCliente = lazy(() => import("../components/Perfil/InformacionCliente"));
const PrevisualizacionDieta = lazy(() => import("../pages/PrevisualizacionDieta"));
const PrevisualizacionEntrenamientos = lazy(() => import("../pages/PrevisualizacionEntrenamientos"));
const HeatmapPanel = lazy(() => import("../components/Perfil/HeatmapPanel"));
const VisualizacionProgreso = lazy(() => import("../components/Perfil/VisualizacionProgreso"));

export default function PerfilCliente() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { success, error: toastError, info } = useToast();
  const { enqueueSnackbar, closeSnackbar } = useSnackbar();

  // refs para usar toasts sin meterlos en deps de callbacks (estabilidad)
  const toastErrorRef = useRef(toastError);
  useEffect(() => { toastErrorRef.current = toastError; }, [toastError]);

  // --- state
  const [cliente, setCliente] = useState(null);
  const [openDialog, setOpenDialog] = useState(false);
  const [openCambiarTarifa, setOpenCambiarTarifa] = useState(false);
  const [openGestionarExtras, setOpenGestionarExtras] = useState(false);
  const [tab, setTab] = useState("info"); // "info" | "dietas" | "entrenamiento"
  const [budgetStatus, setBudgetStatus] = useState({ canEdit: true, estado: null, message: "" });

  // confirm delete
  const [confirmOpen, setConfirmOpen] = useState(false);
  const deleteTimerRef = useRef(null); // para cancelar si hay Undo

  // --- carga estable con AbortController
  const loadData = useCallback(async (signal) => {
    try {
      // 1. Cargar Cliente
      const resCliente = await API.get(`/clientes/${id}`, { signal });
      setCliente(resCliente.data);

      // 2. Cargar Estado Presupuesto
      const resBudget = await API.get(`/clientes/${id}/budget-status`, { signal });
      setBudgetStatus(resBudget.data);

    } catch (e) {
      if (e?.name === "CanceledError" || e?.message === "canceled") return;
      console.error("Error loading data", e);
      toastErrorRef.current?.("No se pudo cargar la información");
    }
  }, [id]);

  useEffect(() => {
    const ctrl = new AbortController();
    loadData(ctrl.signal);
    return () => {
      ctrl.abort();
      if (deleteTimerRef.current) clearTimeout(deleteTimerRef.current);
    };
  }, [loadData]);

  // --- derivados (seguros con cliente=null)
  const isLoading = !cliente;

  const puedeRenovar = useMemo(() => {
    if (!cliente?.fechaFin) return false;
    return new Date(cliente.fechaFin) < new Date();
  }, [cliente?.fechaFin]);

  // Permission checks based on tipoServicio
  const hasDieta = useMemo(() => {
    const tipo = cliente?.tipoServicio;
    if (!tipo) return false;
    return [
      "Dieta",
      "Dieta y asesoramiento",
      "Dieta y Rutina",
      "Mensual",
      "Trimestral",
      "Semestral",
      "Anual"
    ].includes(tipo);
  }, [cliente?.tipoServicio]);

  const hasEntrenamiento = useMemo(() => {
    const tipo = cliente?.tipoServicio;
    if (!tipo) return false;
    return [
      "Rutina",
      "Rutina y asesoramiento",
      "Dieta y Rutina",
      "Mensual",
      "Trimestral",
      "Semestral",
      "Anual"
    ].includes(tipo);
  }, [cliente?.tipoServicio]);

  const canAddProgress = useMemo(() => {
    const tipo = cliente?.tipoServicio;
    if (!tipo) return false;
    return [
      "Dieta y asesoramiento",
      "Rutina y asesoramiento",
      "Mensual",
      "Trimestral",
      "Semestral",
      "Anual"
    ].includes(tipo);
  }, [cliente?.tipoServicio]);

  const fechaInicioFmt = useMemo(
    () => (cliente?.fechaInicio ? new Date(cliente.fechaInicio).toLocaleDateString() : null),
    [cliente?.fechaInicio]
  );
  const fechaFinFmt = useMemo(
    () => (cliente?.fechaFin ? new Date(cliente.fechaFin).toLocaleDateString() : null),
    [cliente?.fechaFin]
  );

  const tabItems = useMemo(() => {
    const base = [{ key: "info", label: "Información y Registro" }];
    if (hasDieta) base.push({ key: "dietas", label: "Dieta" });
    if (hasEntrenamiento) {
        base.push({ key: "entrenamiento", label: "Entrenamiento" });
        base.push({ key: "progreso", label: "Progreso" }); // Nuevo tab
    }
    return base;
  }, [hasDieta, hasEntrenamiento]);

  // Mantén un tab válido si cambia la tarifa
  useEffect(() => {
    if (!tabItems.find((t) => t.key === tab)) setTab("info");
  }, [tabItems, tab]);

  const handleRenovarTarifa = useCallback(async () => {
    if (!cliente) return;
    try {
      // Endpoint ahora crea un presupuesto pendiente con la misma tarifa y extras
      await API.put(`/clientes/${id}/actualizar-tarifa`, {});

      success("Solicitud de renovación creada (Presupuesto Pendiente)");
      startTransition(() => {
        const ctrl = new AbortController();
        loadData(ctrl.signal);
      });
    } catch (e) {
      console.error("PUT /clientes/:id/actualizar-tarifa", e);
      toastErrorRef.current?.("No se pudo procesar la renovación");
    }
  }, [cliente, id, loadData, success]);

  // --- eliminar cliente (confirmación + Undo)
  const requestDelete = useCallback(() => setConfirmOpen(true), []);
  const cancelDelete = useCallback(() => setConfirmOpen(false), []);

  const confirmDelete = useCallback(() => {
    setConfirmOpen(false);
    if (!cliente) return;

    // NO quitamos la UI aquí; esperamos a que finalice o undo
    const key = enqueueSnackbar(`Cliente "${cliente.nombre}" se eliminará`, {
      variant: "info",
      action: (snackbarId) => (
        <Button
          color="inherit"
          size="small"
          onClick={() => {
            if (deleteTimerRef.current) clearTimeout(deleteTimerRef.current);
            deleteTimerRef.current = null;
            closeSnackbar(snackbarId);
            info("Eliminación cancelada");
          }}
        >
          Deshacer
        </Button>
      ),
    });

    deleteTimerRef.current = setTimeout(async () => {
      try {
        await API.delete(`/clientes/${id}`);
        success("Cliente eliminado");
        closeSnackbar(key);
        navigate("/clientes", { replace: true });
      } catch (e) {
        console.error("DELETE /clientes/:id", e);
        toastErrorRef.current?.("No se pudo eliminar el cliente");
        closeSnackbar(key);
      } finally {
        deleteTimerRef.current = null;
      }
    }, 4000);
  }, [cliente, id, enqueueSnackbar, closeSnackbar, info, navigate, success]);

  // Render helpers
  const handleTabChange = useCallback((_, v) => setTab(v), []);
  const openProgreso = useCallback(() => setOpenDialog(true), []);
  const closeProgreso = useCallback(() => setOpenDialog(false), []);
  const openCambiarTarifaCb = useCallback(() => setOpenCambiarTarifa(true), []);
  const closeCambiarTarifaCb = useCallback(() => setOpenCambiarTarifa(false), []);
  const openGestionarExtrasCb = useCallback(() => setOpenGestionarExtras(true), []);
  const closeGestionarExtrasCb = useCallback(() => setOpenGestionarExtras(false), []);

  const reloadCliente = useCallback(() => {
    startTransition(() => {
      const ctrl = new AbortController();
      loadData(ctrl.signal);
    });
  }, [loadData]);

  // Handle session counter updates
  const handleCounterUpdate = useCallback(async (action) => {
    if (!cliente) return;
    try {
      const res = await API.put(`/clientes/${id}/sesiones-counter`, { action });
      
      // Update cliente with new counter value
      setCliente(prev => ({
        ...prev,
        sesionesCounter: res.data.sesionesCounter,
        sesionesLastMonth: res.data.sesionesLastMonth
      }));

      if (res.data.budgetCreated) {
        success(`Presupuesto creado para ${res.data.sesionesCounter} sesiones del mes anterior`);
      }
    } catch (err) {
      console.error('Error updating counter:', err);
      toastError('Error al actualizar el contador');
    }
  }, [cliente, id, success, toastError]);

  // Check for auto-reset on component mount
  useEffect(() => {
    if (!cliente) return;
    const checkReset = async () => {
      try {
        await API.put(`/clientes/${id}/sesiones-counter`, { action: 'check-reset' });
      } catch (err) {
        console.error('Error checking reset:', err);
      }
    };
    checkReset();
  }, [cliente, id]);

  // --- render
  return (
    <Box p={{ xs: 2, md: 4 }}>
      {/* Breadcrumbs */}
      {!isLoading && (
        <Breadcrumbs sx={{ mb: 2 }}>
          <Link component={RouterLink} underline="hover" color="inherit" to="/clientes">
            Clientes
          </Link>
          <Typography color="text.secondary">{cliente?.nombre ?? "Perfil"}</Typography>
        </Breadcrumbs>
      )}

      {/* Alerta de estado del presupuesto */}
      {budgetStatus.estado === "pendiente" && (
        <Alert severity="warning" sx={{ mb: 2 }}>
          El presupuesto de este cliente está pendiente. Las funciones de edición están restringidas.
        </Alert>
      )}

      {/* Header */}
      <Paper
        elevation={0}
        sx={{
          p: { xs: 2, md: 3 },
          mb: 3,
          borderRadius: 3,
          border: "1px solid",
          borderColor: "divider",
          background:
            "linear-gradient(180deg, rgba(255,248,225,0.6) 0%, rgba(255,255,255,0.9) 70%)",
        }}
      >
        <Stack
          direction={{ xs: "column", md: "row" }}
          alignItems={{ xs: "flex-start", md: "center" }}
          justifyContent="space-between"
          spacing={1.5}
        >
          <Box>
            <Typography variant="h4" fontWeight={800}>
              {isLoading ? "Cargando cliente..." : `Perfil de ${cliente.nombre}`}
            </Typography>
            {!isLoading && (
              <Stack direction="row" spacing={1} mt={1} flexWrap="wrap" useFlexGap>
                {fechaInicioFmt && <Chip label={`Inicio: ${fechaInicioFmt}`} size="small" />}
                {fechaFinFmt && (
                  <Chip
                    label={`Fin: ${fechaFinFmt}`}
                    size="small"
                    color={puedeRenovar ? "warning" : "default"}
                  />
                )}
                {cliente.Tiempo_Tarifa && (
                  <Chip label={cliente.Tiempo_Tarifa} size="small" variant="outlined" />
                )}
              </Stack>
            )}
          </Box>

          {/* Botón eliminar */}
          {!isLoading && (
            <Button
              variant="outlined"
              color="error"
              startIcon={<DeleteOutlineIcon />}
              onClick={requestDelete}
            >
              Eliminar
            </Button>
          )}
        </Stack>
      </Paper>

      {/* Tabs dinámicas */}
      <Tabs
        value={tab}
        onChange={handleTabChange}
        textColor="primary"
        indicatorColor="primary"
        sx={{
          mb: 3,
          ".MuiTabs-indicator": { height: 3 },
          ".MuiTab-root": { textTransform: "none", fontWeight: 700 },
        }}
      >
        {(isLoading ? [{ key: "info", label: "Información y Registro" }] : tabItems).map((t) => (
          <Tab 
            key={t.key} 
            value={t.key} 
            label={t.label} 
            disabled={!isLoading && (t.key === "dietas" || t.key === "entrenamiento") && !budgetStatus.canEdit}
          />
        ))}
      </Tabs>

      {/* INFO */}
      {tab === "info" && (
        <>
          <Paper sx={{ p: 3, mb: 3, borderRadius: 3 }} variant="outlined">
            {isLoading ? (
              <Typography color="text.secondary">Cargando datos…</Typography>
            ) : (
              <Suspense fallback={<Skeleton variant="rounded" height={120} />}>
                <InformacionCliente
                  cliente={cliente}
                  puedeRenovar={puedeRenovar}
                  canAddProgress={canAddProgress}
                  onRenovar={handleRenovarTarifa}
                  onAbrirDialogProgreso={openProgreso}
                  onAbrirCambiarTarifa={openCambiarTarifaCb}
                  onAbrirGestionarExtras={openGestionarExtrasCb}
                  onActualizar={reloadCliente}
                  onCounterUpdate={handleCounterUpdate}
                />
              </Suspense>
            )}
          </Paper>

          <Box mb={3}>
            <Suspense fallback={<Skeleton variant="rounded" height={180} />}>
              <HeatmapPanel
                clienteId={id}
              />
            </Suspense>
          </Box>

          {!isLoading && (
            <>
              <Suspense fallback={<Skeleton variant="rounded" height={220} sx={{ mb: 2 }} />}>
                <GraficaPeso historialProgreso={cliente.historialProgreso} />
              </Suspense>
              <Suspense fallback={<Skeleton variant="rounded" height={220} sx={{ my: 2 }} />}>
                <GraficaGrasaCorporal historialProgreso={cliente.historialProgreso} />
              </Suspense>
              <Suspense fallback={<Skeleton variant="rounded" height={220} sx={{ mt: 2 }} />}>
                <GraficaMuscular historialProgreso={cliente.historialProgreso} />
              </Suspense>
            </>
          )}
        </>
      )}

      {/* DIETA */}
      {tab === "dietas" && hasDieta && !isLoading && (
        <Paper
          sx={{
            p: { xs: 2, md: 3 },
            borderRadius: 3,
            border: "1px solid",
            borderColor: "divider",
            background:
              "linear-gradient(180deg, rgba(255,235,205,0.35) 0%, rgba(255,255,255,0.95) 65%)",
          }}
          variant="outlined"
        >
          <Typography variant="h6" fontWeight={700} gutterBottom>
            Dieta
          </Typography>
          <Divider sx={{ mb: 2 }} />
          <Suspense fallback={<Skeleton variant="rounded" height={160} />}>
            <PrevisualizacionDieta clienteId={id} />
          </Suspense>
        </Paper>
      )}

      {/* ENTRENAMIENTO */}
      {tab === "entrenamiento" && hasEntrenamiento && !isLoading && (
        <Paper
          sx={{
            p: { xs: 2, md: 3 },
            borderRadius: 3,
            border: "1px solid",
            borderColor: "divider",
            background:
              "linear-gradient(180deg, rgba(255,235,205,0.35) 0%, rgba(255,255,255,0.95) 65%)",
          }}
          variant="outlined"
        >
          <Typography variant="h6" fontWeight={700} gutterBottom>
            Entrenamiento
          </Typography>
          <Divider sx={{ mb: 2 }} />
          <Suspense fallback={<Skeleton variant="rounded" height={160} />}>
            <PrevisualizacionEntrenamientos clienteId={id} />
          </Suspense>
        </Paper>
      )}

      {/* PROGRESO */}
      {tab === "progreso" && hasEntrenamiento && !isLoading && (
          <Suspense fallback={<Skeleton variant="rounded" height={400} />}>
              <VisualizacionProgreso clienteId={id} />
          </Suspense>
      )}

      {/* Diálogos secundarios */}
      <Suspense fallback={null}>
        <DialogProgreso
          open={openDialog}
          onClose={() => {
            closeProgreso();
            reloadCliente();
          }}
          clienteId={id}
          onProgresoAñadido={() => {
            success("Progreso añadido");
            reloadCliente();
          }}
          asesorId={cliente?.asesorId}
        />
      </Suspense>

      <Suspense fallback={null}>
        <DialogCambiarTarifa
          open={openCambiarTarifa}
          onClose={closeCambiarTarifaCb}
          clienteId={id}
          onTarifaActualizada={() => {
            success("Solicitud creada (Presupuesto Pendiente)");
            reloadCliente();
          }}
          asesorId={cliente?.asesorId}
        />
      </Suspense>

      <Suspense fallback={null}>
        <DialogGestionarExtras
          open={openGestionarExtras}
          onClose={closeGestionarExtrasCb}
          cliente={cliente || {}}
          onActualizar={() => {
            success("Solicitud creada (Presupuesto Pendiente)");
            reloadCliente();
          }}
        />
      </Suspense>

      {/* Confirmación eliminar */}
      <ConfirmDialog
        open={confirmOpen}
        onClose={cancelDelete}
        title="¿Eliminar cliente?"
        subtitle={cliente ? `Se eliminará "${cliente.nombre}". Podrás deshacer durante unos segundos.` : ""}
        confirmText="Eliminar"
        confirmColor="error"
        onConfirm={confirmDelete}
      />
    </Box>
  );
}
