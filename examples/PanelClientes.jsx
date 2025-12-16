import {
  useEffect, useMemo, useRef, useState, useCallback,
  useDeferredValue, startTransition, Suspense, lazy
} from "react";
import { useAuth } from "../context/AuthContext";
import { extractAsesorId } from "../utils/auth";
import {
  Box, Typography, Grid, Paper, TextField, Button, Chip, Stack, Divider, Skeleton,
  FormControl, InputLabel, Select, MenuItem, OutlinedInput, Pagination,
  Dialog, DialogTitle, DialogContent, DialogActions, Tabs, Tab
} from "@mui/material";
import AddIcon from "@mui/icons-material/Add";
import ClearAllIcon from "@mui/icons-material/ClearAll";
import EmailIcon from "@mui/icons-material/Email";
import { useSnackbar } from "notistack";
import API from "../services/api";
import { useToast } from "../utils/toast";

/** Code-splitting (carga bajo demanda) */
const ClienteCard         = lazy(() => import("../components/ClienteCard"));
const NuevoClienteDrawer  = lazy(() => import("../components/NuevoClienteDrawer"));
const EmptyState          = lazy(() => import("../components/EmptyState"));
const ConfirmDialog       = lazy(() => import("../components/ConfirmDialog"));
const BulkEmailDialog     = lazy(() => import("../components/BulkEmailDialog"));

/* ——————————————————— Helpers ——————————————————— */
const OBJETIVOS = [
  "Pérdida de peso", "Mantenimiento", "Ganar masa muscular",
  "Mejorar rendimiento", "Aumentar fuerza", "Mejorar salud general", "Definición",
];


const asArrayObjetivos = (val) => {
  if (Array.isArray(val)) return val.map(String);
  if (typeof val === "string") {
    return val.split(/[;,·|\-]/g).map((s) => s.trim()).filter(Boolean);
  }
  return [];
};

/** Debounce barato para inputs controlados */
function useDebouncedState(initial, delay = 200) {
  const [val, setVal] = useState(initial);
  const [debounced, setDebounced] = useState(initial);
  useEffect(() => {
    const t = setTimeout(() => setDebounced(val), delay);
    return () => clearTimeout(t);
  }, [val, delay]);
  return [debounced, setVal, val];
}

export default function PanelClientes() {
  const { success, error: toastError, info } = useToast();
  const { enqueueSnackbar, closeSnackbar } = useSnackbar();

  const toastErrorRef = useRef(toastError);
  useEffect(() => { toastErrorRef.current = toastError; }, [toastError]);

  const [clientes, setClientes] = useState([]);   // datos normalizados
  const [loading, setLoading]   = useState(true);
  const [tarifas, setTarifas] = useState([]);

  const { user, token } = useAuth();
  const asesorId = useMemo(() => extractAsesorId(user, token), [user, token]);

  // filtros
  const [qDebounced, setQ, qRaw] = useDebouncedState("", 200);
  const qDef = useDeferredValue(qDebounced);

  const [fTarifa, setFTarifa] = useState("");
  const fTarifaDef = useDeferredValue(fTarifa);

  const [fObjetivos, setFObjetivos] = useState([]);
  const fObjetivosDef = useDeferredValue(fObjetivos);

  // paginación
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const topRef = useRef(null);

  // drawer crear
  const [openNew, setOpenNew] = useState(false);

  // bulk email dialog
  const [openBulkEmail, setOpenBulkEmail] = useState(false);

  // confirm dialog + control de eliminación
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [clientToDelete, setClientToDelete] = useState(null);
  const pendingDeletes = useRef(new Map()); // id -> { cliente, index, timer }

  // ——————————————————— Carga estable (sin deps reactivas) ———————————————————
  const loadClientes = useCallback(async (signal) => {
    setLoading(true);
    try {
      const res = await API.get(`/clientes/asesor/${asesorId}`, { signal });
      const now = Date.now();

      const data = (res.data || []).map((c) => {
        const _lc_nombre     = c?.nombre?.toLowerCase?.() || "";
        const _lc_email      = c?.email?.toLowerCase?.() || "";
        const _lc_tel        = String(c?.telefono ?? "").toLowerCase();
        const _arr_objetivos = asArrayObjetivos(c?.objetivos);
        const finTs          = c?.fechaFin ? new Date(c.fechaFin).getTime() : 0;
        const _isActivo      = Boolean(finTs && finTs >= now);
        return { ...c, _lc_nombre, _lc_email, _lc_tel, _arr_objetivos, _isActivo };
      });

      setClientes(data);
    } catch (e) {
      if (e?.name !== "CanceledError" && e?.message !== "canceled") {
        console.error("GET /clientes", e);
        // usa ref para no romper la estabilidad del callback
        toastErrorRef.current?.("No se pudieron cargar los clientes");
      }
    } finally {
      setLoading(false);
    }
  }, []); // <- sin deps: identidad SIEMPRE estable

  const handleCreated = useCallback(() => {
    success("Cliente creado correctamente");
    setOpenNew(false);
    startTransition(() => {
      const ctrl = new AbortController();
      loadClientes(ctrl.signal);
    });
  }, [success, loadClientes]);

  useEffect(() => {
    const ctrl = new AbortController();
    loadClientes(ctrl.signal);
    return () => ctrl.abort();
  }, [loadClientes]);

  // Load tarifas
  useEffect(() => {
    const loadTarifas = async () => {
      try {
        const res = await API.get("/tarifas");
        setTarifas(res.data || []);
      } catch (e) {
        console.error("Error loading tarifas", e);
      }
    };
    loadTarifas();
  }, []);

  // ——————————————————— Delete + Undo ———————————————————
  const requestDelete = useCallback((cliente) => {
    setClientToDelete(cliente);
    setConfirmOpen(true);
  }, []);

  const cancelDelete = useCallback(() => {
    setConfirmOpen(false);
    setClientToDelete(null);
  }, []);

  const confirmDelete = useCallback(() => {
    if (!clientToDelete) return;
    const target = clientToDelete;
    const id = target._id;

    setConfirmOpen(false);

    const index = clientes.findIndex((c) => c._id === id);
    if (index === -1) return;

    // 1) quitar de UI
    setClientes((prev) => {
      const next = prev.slice();
      next.splice(index, 1);
      return next;
    });

    // 2) limpia pending anterior si lo hubiera
    const previous = pendingDeletes.current.get(id);
    if (previous?.timer) clearTimeout(previous.timer);

    // 3) Snackbar con "Deshacer"
    const key = enqueueSnackbar(`Cliente "${target.nombre}" eliminado`, {
      variant: "info",
      action: (snackbarId) => (
        <Button
          color="inherit"
          size="small"
          onClick={() => {
            const pending = pendingDeletes.current.get(id);
            if (pending?.timer) clearTimeout(pending.timer);
            setClientes((curr) => {
              const restored = curr.slice();
              const insertAt = Math.min(pending?.index ?? 0, curr.length);
              restored.splice(insertAt, 0, pending?.cliente ?? target);
              return restored;
            });
            pendingDeletes.current.delete(id);
            closeSnackbar(snackbarId);
            info("Eliminación cancelada");
          }}
        >
          Deshacer
        </Button>
      ),
    });

    // 4) Borrado real diferido
    const timer = setTimeout(async () => {
      try {
        await API.delete(`/clientes/${id}`);
        success("Cliente eliminado");
      } catch (e) {
        console.error("DELETE /clientes/:id", e);
        toastErrorRef.current?.("No se pudo eliminar el cliente");
        // revertir UI si backend falla
        setClientes((curr) => {
          const restored = curr.slice();
          const insertAt = Math.min(index, curr.length);
          restored.splice(insertAt, 0, target);
          return restored;
        });
      } finally {
        closeSnackbar(key);
        pendingDeletes.current.delete(id);
      }
    }, 4000);

    // 5) guardar pending
    pendingDeletes.current.set(id, { cliente: target, index, timer });
  }, [clientToDelete, clientes, closeSnackbar, enqueueSnackbar, info, success]);

  // ——————————————————— Toggle Estado (Baja/Activo) ———————————————————
  const handleToggleStatus = useCallback(async (cliente) => {
    const nuevoEstado = cliente.estado === "Baja" ? "Activo" : "Baja";
    // Optimistic update
    setClientes(prev => prev.map(c => 
      c._id === cliente._id ? { ...c, estado: nuevoEstado } : c
    ));
    
    try {
      await API.put(`/clientes/${cliente._id}/status`, { estado: nuevoEstado });
      success(`Cliente marcado como ${nuevoEstado}`);
    } catch (e) {
      console.error("PUT /status", e);
      // Revert
      setClientes(prev => prev.map(c => 
        c._id === cliente._id ? { ...c, estado: cliente.estado } : c
      ));
      toastErrorRef.current?.("Error al actualizar estado");
    }
  }, [success]);

  // ——————————————————— Filtros + Tabs ———————————————————
  // Tab state: 0 = Activos, 1 = Baja
  const [tabIndex, setTabIndex] = useState(0);

  const filtrosActivos = !!qRaw || !!fTarifa || fObjetivos.length > 0;

  const clearFilters = useCallback(() => {
    startTransition(() => {
      setQ("");
      setFTarifa("");
      setFObjetivos([]);
      setPage(1);
    });
    info("Filtros limpiados");
  }, [info]);

  const { total, totalActivos, totalBajas } = useMemo(() => {
    let activos = 0;
    let bajas = 0;
    for (const c of clientes) {
       if (c.estado === "Baja") {
         bajas++;
       } else {
         activos++; // Consideramos 'Activos' a todo lo que no sea explícitamente 'Baja' (incluye vencidos, etc)
       }
    }
    return { total: clientes.length, totalActivos: activos, totalBajas: bajas };
  }, [clientes]);

  const filtered = useMemo(() => {
    const needle = qDef.trim().toLowerCase();
    const wantTarifa = Boolean(fTarifaDef);
    const wantObjs = fObjetivosDef.length > 0;
    const wantBaja = tabIndex === 1;

    // Filter by Tab first
    let base = clientes.filter(c => {
       if (wantBaja) return c.estado === "Baja";
       return c.estado !== "Baja"; // Default tab shows everything NOT explicitly Baja
    });

    if (!needle && !wantTarifa && !wantObjs) return base;

    return base.filter((c) => {
      const hayTexto = !needle
        ? true
        : (c._lc_nombre.includes(needle) || c._lc_email.includes(needle) || c._lc_tel.includes(needle));

      const okTarifa = wantTarifa ? c.Tarifa === fTarifaDef : true;

      const okObjs = wantObjs
        ? (c._arr_objetivos?.some((o) => fObjetivosDef.includes(o)) ?? false)
        : true;

      return hayTexto && okTarifa && okObjs;
    });
  }, [clientes, qDef, fTarifaDef, fObjetivosDef, tabIndex]);

  // ——— Paginación sobre el filtrado ———
  const totalFiltered = filtered.length;
  const totalPages = Math.max(1, Math.ceil(totalFiltered / pageSize));

  // Si cambian filtros o pageSize o TAB, resetea a página 1
  useEffect(() => {
    setPage(1);
  }, [qDef, fTarifaDef, fObjetivosDef, pageSize, tabIndex]);

  // Clamp si la página actual se sale tras un borrado/filtro
  useEffect(() => {
    if (page > totalPages) setPage(totalPages);
  }, [page, totalPages]);

  const pageItems = useMemo(() => {
    const start = (page - 1) * pageSize;
    const end = start + pageSize;
    return filtered.slice(start, end);
  }, [filtered, page, pageSize]);

  const onChangePage = useCallback((_, value) => {
    setPage(value);
    if (topRef.current) {
      topRef.current.scrollIntoView({ behavior: "smooth", block: "start" });
    } else {
      window.scrollTo({ top: 0, behavior: "smooth" });
    }
  }, []);

  // ——————————————————— Render ———————————————————
  return (
    <Box p={{ xs: 2, md: 4 }} ref={topRef}>
      {/* HEADER */}
      <Paper
        elevation={0}
        sx={{
          p: { xs: 2, md: 3 }, mb: 3, borderRadius: 3, border: "1px solid", borderColor: "divider",
          background: "linear-gradient(180deg, rgba(246,247,251,0.7) 0%, rgba(255,255,255,1) 50%)",
        }}
      >
        <Stack
          direction={{ xs: "column", md: "row" }}
          spacing={2}
          alignItems={{ xs: "flex-start", md: "center" }}
          justifyContent="space-between"
        >
          <Box>
            <Typography variant="h4" fontWeight={800}>Clientes</Typography>
            <Stack direction="row" spacing={1} mt={1} flexWrap="wrap" useFlexGap>
              <Chip label={`Total: ${total}`} variant="outlined" sx={{ borderRadius: 2 }} />
              <Chip label={`Activos: ${totalActivos}`} color="success" variant="outlined" sx={{ borderRadius: 2 }} />
              <Chip label={`Baja: ${totalBajas}`} color="error" variant="outlined" sx={{ borderRadius: 2 }} />
              {filtrosActivos && (
                <Chip
                  icon={<ClearAllIcon />}
                  label="Limpiar filtros"
                  onClick={clearFilters}
                  sx={{ borderRadius: 2 }}
                />
              )}
            </Stack>
          </Box>

          <Stack direction={{ xs: "column", sm: "row" }} spacing={1.25} useFlexGap flexWrap="wrap">
            <TextField
              size="small"
              placeholder="Buscar por nombre, email o teléfono…"
              value={qRaw}
              onChange={(e) => setQ(e.target.value)}
              sx={{ minWidth: { xs: "100%", sm: 320 } }}
            />

            <FormControl size="small" sx={{ minWidth: 170 }}>
              <InputLabel>Tarifa</InputLabel>
              <Select
                label="Tarifa"
                value={fTarifa}
                onChange={(e) => setFTarifa(e.target.value)}
              >
                <MenuItem value="">Todas</MenuItem>
                {tarifas.map((t) => (
                  <MenuItem key={t._id} value={t.nombre}>{t.nombre}</MenuItem>
                ))}
              </Select>
            </FormControl>

            <FormControl size="small" sx={{ minWidth: 220 }}>
              <InputLabel>Objetivos</InputLabel>
              <Select
                multiple
                value={fObjetivos}
                onChange={(e) => setFObjetivos(e.target.value)}
                input={<OutlinedInput label="Objetivos" />}
                renderValue={(selected) => (
                  <Box sx={{ display: "flex", flexWrap: "wrap", gap: 0.5 }}>
                    {selected.map((value) => (<Chip key={value} label={value} />))}
                  </Box>
                )}
              >
                {OBJETIVOS.map((o) => (
                  <MenuItem key={o} value={o}>{o}</MenuItem>
                ))}
              </Select>
            </FormControl>

            {/* Tamaño de página */}
            <FormControl size="small" sx={{ minWidth: 140 }}>
              <InputLabel>Tamaño</InputLabel>
              <Select
                label="Tamaño"
                value={pageSize}
                onChange={(e) => setPageSize(Number(e.target.value))}
              >
                {[10, 20, 50, 100].map((n) => (
                  <MenuItem key={n} value={n}>{n} por página</MenuItem>
                ))}
              </Select>
            </FormControl>

            <Button
              startIcon={<EmailIcon />}
              variant="outlined"
              sx={{ borderRadius: 2 }}
              onClick={() => setOpenBulkEmail(true)}
              disabled={filtered.filter(c => c.email).length === 0}
            >
              Enviar Email Masivo
            </Button>

            <Button
              startIcon={<AddIcon />}
              variant="contained"
              sx={{ borderRadius: 2 }}
              onClick={() => setOpenNew(true)}
            >
              Nuevo cliente
            </Button>
          </Stack>
        </Stack>
      </Paper>

      {/* Tabs SECTION */}
      <Box sx={{ borderBottom: 1, borderColor: 'divider', mb: 2 }}>
        <Tabs value={tabIndex} onChange={(e, val) => setTabIndex(val)} aria-label="client tabs">
          <Tab label={`Activos (${totalActivos})`} />
          <Tab label={`Baja (${totalBajas})`} />
        </Tabs>
      </Box>

      {/* LISTA */}
      <Grid container spacing={2}>
        {loading ? (
          Array.from({ length: Math.min(pageSize, 6) }).map((_, i) => (
            <Grid item xs={12} key={i}>
              <Skeleton variant="rounded" height={112} />
            </Grid>
          ))
        ) : totalFiltered > 0 ? (
          pageItems.map((c) => (
            <Grid item xs={12} key={c._id}>
              <Suspense fallback={<Skeleton variant="rounded" height={112} />}>
                <ClienteCard 
                   cliente={c} 
                   onDelete={() => requestDelete(c)} 
                   onToggleStatus={() => handleToggleStatus(c)}
                />
              </Suspense>
            </Grid>
          ))
        ) : (
          <Grid item xs={12}>
            <Paper variant="outlined" sx={{ p: 0, borderRadius: 3, overflow: "hidden" }}>
              <Suspense fallback={<Skeleton variant="rounded" height={140} />}>
                <EmptyState
                  title="No hay clientes que coincidan con el filtro"
                  subtitle="Ajusta el buscador o crea un nuevo cliente."
                  actionLabel="Nuevo cliente"
                  onAction={() => setOpenNew(true)}
                />
              </Suspense>
            </Paper>
          </Grid>
        )}
      </Grid>
      
      {/* Paginación */}
      {!loading && totalFiltered > 0 && (
        <Stack direction="row" alignItems="center" justifyContent="center" sx={{ mt: 2 }}>
          <Pagination
            color="primary"
            count={totalPages}
            page={page}
            onChange={onChangePage}
            siblingCount={1}
            boundaryCount={1}
            shape="rounded"
          />
        </Stack>
      )}

      <Divider sx={{ my: 3 }} />
      <Typography variant="caption" color="text.secondary">
        Vista de clientes · actualizado
      </Typography>

      {/* DRAWER NUEVO CLIENTE */}
      <Suspense fallback={null}>
        <NuevoClienteDrawer
          open={openNew}
          onClose={() => setOpenNew(false)}
          onCreated={handleCreated}
        />
      </Suspense>

      {/* CONFIRMAR BORRADO */}
      <Suspense fallback={null}>
        <ConfirmDialog
          open={confirmOpen}
          onClose={cancelDelete}
          title="¿Eliminar cliente?"
          subtitle={clientToDelete ? `Se eliminará "${clientToDelete.nombre}". Podrás deshacer durante unos segundos.` : ""}
          confirmText="Eliminar"
          confirmColor="error"
          onConfirm={confirmDelete}
        />
      </Suspense>

      {/* BULK EMAIL DIALOG */}
      <Suspense fallback={null}>
        <BulkEmailDialog
          open={openBulkEmail}
          onClose={() => setOpenBulkEmail(false)}
          clientes={filtered}
          onSuccess={success}
          onError={toastErrorRef.current}
        />
      </Suspense>
    </Box>
  );
}
