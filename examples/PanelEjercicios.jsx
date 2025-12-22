import React, {
  useCallback,
  useEffect,
  useMemo,
  useState,
} from "react";
import {
  Box, Paper, Stack, Typography, Button, TextField, IconButton, Tooltip,
  Dialog, DialogTitle, DialogContent, DialogActions, MenuItem, Grid, Table,
  TableHead, TableRow, TableCell, TableBody, Avatar, Snackbar, Alert, Drawer, Chip,
} from "@mui/material";

import AddIcon from "@mui/icons-material/Add";
import EditIcon from "@mui/icons-material/Edit";
import DeleteOutlineIcon from "@mui/icons-material/DeleteOutline";
import FitnessCenterIcon from "@mui/icons-material/FitnessCenter";
import SearchIcon from "@mui/icons-material/Search";
import FilterAltIcon from "@mui/icons-material/FilterAlt";
import LinkIcon from "@mui/icons-material/Link";
import CloseIcon from "@mui/icons-material/Close";

import {
  QueryClient,
  QueryClientProvider,
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";

import API from "../services/api";

const BASE = "/ejercicios";

// 🔥 LISTAS FIJAS — SIEMPRE SE USAN ESTAS
const GRUPOS_FALLBACK = ["Pecho Superior", "Pecho Inferior", "Pecho Medio", "Trapecio", "Dorsal", "Espalda Baja", "Cuello", "Cuadriceps", "Isquiotibiales", "Gluteos", "Gemelos", "Hombros", "Bíceps", "Tríceps", "Abdominales", "Cardio", "Otro"];
const EQUIPOS_FALLBACK = ["Mancuernas", "Barra", "Máquinas", "Cuerpo libre", "Bandas elásticas", "TRX", "Balón medicinal", "Rueda abdominal", "Comba", "Peso corporal", "Poleas"];
const NIVELES_FALLBACK = ["Principiante", "Intermedio", "Avanzado"];

const headerGradient = "linear-gradient(180deg, rgba(246,247,251,0.7) 0%, rgba(255,255,255,1) 45%)";


const youtubeId = (url = "") => {
  try {
    const u = new URL(url);
    if (u.hostname.includes("youtu.be")) return u.pathname.slice(1);
    if (u.hostname.includes("youtube.com")) {
      if (u.searchParams.get("v")) return u.searchParams.get("v");
      const parts = u.pathname.split("/");
      const idx = parts.findIndex((p) => p === "embed");
      if (idx >= 0 && parts[idx + 1]) return parts[idx + 1];
    }
  } catch {}
  return null;
};
const youtube = (url) => {
  const id = youtubeId(url);
  return id ? `https://www.youtube.com/embed/${id}` : null;
};

function useDebouncedValue(value, delay = 300) {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const t = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(t);
  }, [value, delay]);
  return debounced;
}

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 60 * 1000,
      gcTime: 5 * 60 * 1000,
      refetchOnWindowFocus: false,
      retry: 1,
      placeholderData: (prev) => prev,
    },
  },
});

const fetchEjercicios = async ({ signal, queryKey }) => {
  const [, q, grupo, equipo, nivel, page, limit] = queryKey;
  const params = {
    q: q || undefined,
    grupo: grupo || undefined,
    equipo: equipo || undefined,
    nivel: nivel || undefined,
    page,
    limit,
    sort: "nombre",
    order: "asc",
  };
  const res = await API.get(BASE, { params, signal });
  const data = res.data;
  const items = Array.isArray(data) ? data : (data?.items || []);
  const total = Array.isArray(data) ? data.length : (data?.total ?? items.length);
  return { items, total };
};

const fetchEjercicioById = async ({ signal, queryKey }) => {
  const [, id] = queryKey;
  const res = await API.get(`${BASE}/${id}`, { signal });
  return res.data;
};

// =========================================================
// COMPONENTE PRINCIPAL
// =========================================================

function PanelEjerciciosInner() {
  const qc = useQueryClient();

  const [q, setQ] = useState("");
  const [grupo, setGrupo] = useState("");
  const [equipo, setEquipo] = useState("");
  const [nivel, setNivel] = useState("");
  const [page, setPage] = useState(1);
  const limit = 50;

  const debounced = useDebouncedValue({ q, grupo, equipo, nivel, page }, 300);

  const listKey = useMemo(
    () => ["ejercicios", debounced.q || "", debounced.grupo || "", debounced.equipo || "", debounced.nivel || "", debounced.page, limit],
    [debounced, limit]
  );

  const { data: listData, isFetching } = useQuery({
    queryKey: listKey,
    queryFn: fetchEjercicios,
  });

  const items = listData?.items || [];
  const total = listData?.total || 0;

  const [drawerOpen, setDrawerOpen] = useState(false);
  const [selected, setSelected] = useState(null);
  const [openForm, setOpenForm] = useState(false);
  const [editing, setEditing] = useState(null);
  const [form, setForm] = useState({
    nombre: "",
    grupo: "",
    equipo: "",
    nivel: "",
    urlVideo: "",
    instrucciones: "",
  });

  const [openDelete, setOpenDelete] = useState(false);
  const [toDelete, setToDelete] = useState(null);
  const [toast, setToast] = useState({ open: false, msg: "", sev: "success" });

  // ===============================
  // CRUD MUTATIONS
  // ===============================

  const createMut = useMutation({
    mutationFn: (payload) => API.post(BASE, payload),
    onSuccess: () => {
      setToast({ open: true, msg: "Ejercicio creado", sev: "success" });
      qc.invalidateQueries({ queryKey: ["ejercicios"] });
    },
  });

  const updateMut = useMutation({
    mutationFn: ({ id, payload }) => API.put(`${BASE}/${id}`, payload),
    onSuccess: () => {
      setToast({ open: true, msg: "Ejercicio actualizado", sev: "success" });
      qc.invalidateQueries({ queryKey: ["ejercicios"] });
      if (selected?._id) qc.invalidateQueries({ queryKey: ["ejercicio", selected._id] });
    },
  });

  const deleteMut = useMutation({
    mutationFn: (id) => API.delete(`${BASE}/${id}`),
    onSuccess: () => {
      setToast({ open: true, msg: "Ejercicio eliminado", sev: "success" });
      qc.invalidateQueries({ queryKey: ["ejercicios"] });
      setDrawerOpen(false);
      setSelected(null);
    },
  });

  // FORM handlers
  const openCreate = () => {
    setEditing(null);
    setForm({ nombre: "", grupo: "", equipo: "", nivel: "", urlVideo: "", instrucciones: "" });
    setOpenForm(true);
  };

  const openEdit = (row) => {
    setEditing(row);
    setForm({
      nombre: row?.nombre || "",
      grupo: row?.grupo || "",
      equipo: row?.equipo || "",
      nivel: row?.nivel || "",
      urlVideo: row?.urlVideo || "",
      instrucciones: row?.instrucciones || "",
    });
    setOpenForm(true);
  };

  const submitForm = async () => {
    if (!form.nombre.trim()) {
      setToast({ open: true, msg: "El nombre es obligatorio", sev: "warning" });
      return;
    }

    if (!editing) await createMut.mutateAsync(form);
    else await updateMut.mutateAsync({ id: editing._id, payload: form });

    setOpenForm(false);
  };

  const doDelete = async () => {
    if (!toDelete) return;
    await deleteMut.mutateAsync(toDelete._id);
    setOpenDelete(false);
    setToDelete(null);
  };

  // Prefetch detalle
  const { data: detalleData } = useQuery({
    queryKey: ["ejercicio", selected?._id],
    queryFn: fetchEjercicioById,
    enabled: Boolean(selected?._id),
    initialData: selected || undefined,
  });

  // ============
  // RENDER
  // ============

  const Header = (
    <TableHead>
      <TableRow sx={{ backgroundColor: "rgba(0,0,0,0.02)" }}>
        <TableCell sx={{ fontWeight: 700 }}>Nombre</TableCell>
        <TableCell>Grupo</TableCell>
        <TableCell>Equipo</TableCell>
        <TableCell>Nivel</TableCell>
        <TableCell>Video</TableCell>
        <TableCell width={120} align="right">Acciones</TableCell>
      </TableRow>
    </TableHead>
  );

  return (
    <Box p={{ xs: 2, md: 4 }}>
      {/* HEADER */}
      <Paper elevation={0} sx={{ p: 3, mb: 3, borderRadius: 3, border: "1px solid", borderColor: "divider", background: headerGradient }}>
        <Stack direction="row" justifyContent="space-between">
          <Stack>
            <Stack direction="row" spacing={1} alignItems="center">
              <Avatar><FitnessCenterIcon /></Avatar>
              <Typography variant="h4" fontWeight={800}>Ejercicios</Typography>
            </Stack>
            <Typography variant="body2" color="text.secondary">
              Total: <strong>{total}</strong>
            </Typography>
          </Stack>

          <Stack direction="row" spacing={1}>
            <Button
              variant="outlined"
              startIcon={<FilterAltIcon />}
              onClick={() => { setQ(""); setGrupo(""); setEquipo(""); setNivel(""); setPage(1); }}
            >
              Limpiar filtros
            </Button>
            <Button variant="contained" startIcon={<AddIcon />} onClick={openCreate}>Nuevo ejercicio</Button>
          </Stack>
        </Stack>
      </Paper>

      {/* FILTROS */}
      <Paper elevation={0} sx={{ p: 2, mb: 2, borderRadius: 3, border:"1px solid", borderColor:"divider" }}>
        <Grid container spacing={2} alignItems="center">
          
          {/* BUSCAR */}
          <Grid item xs={12} md={4}>
            <TextField
              fullWidth size="small" label="Buscar"
              value={q}
              onChange={(e) => { setQ(e.target.value); setPage(1); }}
              InputProps={{ startAdornment: <SearchIcon sx={{ mr:1 }} /> }}
            />
          </Grid>

          {/* GRUPO */}
          <Grid item xs={6} md={2.5}>
            <TextField select fullWidth size="small" label="Grupo" value={grupo} onChange={(e)=>{ setGrupo(e.target.value); setPage(1); }}>
              <MenuItem value="">Todos</MenuItem>
              {GRUPOS_FALLBACK.map((g)=>(
                <MenuItem key={g} value={g}>{g}</MenuItem>
              ))}
            </TextField>
          </Grid>

          {/* EQUIPO */}
          <Grid item xs={6} md={2.5}>
            <TextField select fullWidth size="small" label="Equipo" value={equipo} onChange={(e)=>{ setEquipo(e.target.value); setPage(1); }}>
              <MenuItem value="">Todos</MenuItem>
              {EQUIPOS_FALLBACK.map((g)=>(
                <MenuItem key={g} value={g}>{g}</MenuItem>
              ))}
            </TextField>
          </Grid>

          {/* NIVEL */}
          <Grid item xs={6} md={2}>
            <TextField select fullWidth size="small" label="Nivel" value={nivel} onChange={(e)=>{ setNivel(e.target.value); setPage(1); }}>
              <MenuItem value="">Todos</MenuItem>
              {NIVELES_FALLBACK.map((g)=>(
                <MenuItem key={g} value={g}>{g}</MenuItem>
              ))}
            </TextField>
          </Grid>
        </Grid>
      </Paper>

      {/* TABLA */}
      <Paper elevation={0} sx={{ p:0, borderRadius:3, border:"1px solid", borderColor:"divider" }}>
        <Table size="small" stickyHeader>
          {Header}
          <TableBody>
            {items.map((row)=>(
              <TableRow key={row._id} hover
                sx={{ cursor:"pointer" }}
                onClick={()=>{ setSelected(row); setDrawerOpen(true); }}
              >
                <TableCell sx={{ fontWeight:600 }}>{row.nombre}</TableCell>
                <TableCell>{row.grupo || "-"}</TableCell>
                <TableCell>{row.equipo || "-"}</TableCell>
                <TableCell>{row.nivel || "-"}</TableCell>
                <TableCell>
                  {row.urlVideo ? (
                    <Tooltip title="Abrir video">
                      <IconButton size="small" component="a" href={row.urlVideo} target="_blank">
                        <LinkIcon />
                      </IconButton>
                    </Tooltip>
                  ) : "–"}
                </TableCell>
                <TableCell align="right" onClick={(e)=>e.stopPropagation()}>
                  <Tooltip title="Editar"><IconButton size="small" onClick={()=>openEdit(row)}><EditIcon /></IconButton></Tooltip>
                  <Tooltip title="Eliminar"><IconButton size="small" color="error" onClick={()=>{ setToDelete(row); setOpenDelete(true); }}><DeleteOutlineIcon /></IconButton></Tooltip>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </Paper>

      {/* DRAWER DETALLE */}
      <Drawer
        anchor="right"
        open={drawerOpen}
        onClose={()=>{ setDrawerOpen(false); setSelected(null); }}
        PaperProps={{ sx:{ width:{ xs:"100%", sm:420 }} }}
      >
        <Box sx={{ p:2, borderBottom:"1px solid", borderColor:"divider", background:headerGradient }}>
          <Stack direction="row" justifyContent="space-between">
            <Stack direction="row" spacing={1} alignItems="center">
              <Avatar><FitnessCenterIcon /></Avatar>
              <Typography variant="h6" fontWeight={800}>
                {detalleData?.nombre || selected?.nombre}
              </Typography>
            </Stack>
            <IconButton onClick={()=>{ setDrawerOpen(false); setSelected(null); }}>
              <CloseIcon />
            </IconButton>
          </Stack>

          <Stack direction="row" spacing={1} mt={1}>
            {detalleData?.grupo && <Chip label={detalleData.grupo} size="small" />}
            {detalleData?.equipo && <Chip label={detalleData.equipo} size="small" />}
            {detalleData?.nivel && <Chip label={detalleData.nivel} size="small" />}
          </Stack>
        </Box>

        <Box sx={{ p:2 }}>
          {detalleData?.urlVideo && youtube(detalleData.urlVideo) && (
            <Box sx={{ position:"relative", pt:"56.25%", borderRadius:2, overflow:"hidden", mb:2 }}>
              <iframe src={youtube(detalleData.urlVideo)} style={{ position:"absolute", inset:0, width:"100%", height:"100%", border:0 }} allowFullScreen />
            </Box>
          )}

          <Typography variant="subtitle2" color="text.secondary">Instrucciones</Typography>
          <Paper variant="outlined" sx={{ p:1.5, borderRadius:2, minHeight:100 }}>
            {detalleData?.instrucciones || "—"}
          </Paper>

          <Stack direction="row" spacing={1.5} mt={2}>
            <Button variant="outlined" startIcon={<EditIcon />} onClick={()=>openEdit(detalleData)}>Editar</Button>
            <Button variant="outlined" color="error" startIcon={<DeleteOutlineIcon />} onClick={()=>{ setToDelete(detalleData); setOpenDelete(true); }}>
              Eliminar
            </Button>
          </Stack>
        </Box>
      </Drawer>

      {/* FORMULARIO */}
      <Dialog open={openForm} onClose={()=>setOpenForm(false)} fullWidth maxWidth="md">
        <DialogTitle sx={{ fontWeight:800 }}>
          {editing ? "Editar ejercicio" : "Nuevo ejercicio"}
        </DialogTitle>
        <DialogContent dividers>
          <Grid container spacing={2}>

            <Grid item xs={12} md={6}>
              <TextField label="Nombre *" fullWidth value={form.nombre}
                onChange={(e)=>setForm((f)=>({ ...f, nombre:e.target.value }))} />
            </Grid>

            <Grid item xs={6} md={3}>
              <TextField select fullWidth label="Grupo" value={form.grupo}
                onChange={(e)=>setForm((f)=>({ ...f, grupo:e.target.value }))}>
                <MenuItem value="">—</MenuItem>
                {GRUPOS_FALLBACK.map((g)=><MenuItem key={g} value={g}>{g}</MenuItem>)}
              </TextField>
            </Grid>

            <Grid item xs={6} md={3}>
              <TextField select fullWidth label="Equipo" value={form.equipo}
                onChange={(e)=>setForm((f)=>({ ...f, equipo:e.target.value }))}>
                <MenuItem value="">—</MenuItem>
                {EQUIPOS_FALLBACK.map((g)=><MenuItem key={g} value={g}>{g}</MenuItem>)}
              </TextField>
            </Grid>

            <Grid item xs={6} md={3}>
              <TextField select fullWidth label="Nivel" value={form.nivel}
                onChange={(e)=>setForm((f)=>({ ...f, nivel:e.target.value }))}>
                <MenuItem value="">—</MenuItem>
                {NIVELES_FALLBACK.map((g)=><MenuItem key={g} value={g}>{g}</MenuItem>)}
              </TextField>
            </Grid>

            <Grid item xs={12} md={9}>
              <TextField fullWidth label="URL Video" value={form.urlVideo}
                onChange={(e)=>setForm((f)=>({ ...f, urlVideo:e.target.value }))} />
            </Grid>

            <Grid item xs={12}>
              <TextField fullWidth multiline minRows={3} label="Instrucciones" value={form.instrucciones}
                onChange={(e)=>setForm((f)=>({ ...f, instrucciones:e.target.value }))} />
            </Grid>
          </Grid>
        </DialogContent>

        <DialogActions sx={{ p:2 }}>
          <Button onClick={()=>setOpenForm(false)}>Cancelar</Button>
          <Button variant="contained" onClick={submitForm}>
            {editing ? "Guardar cambios" : "Crear ejercicio"}
          </Button>
        </DialogActions>
      </Dialog>

      {/* CONFIRMAR DELETE */}
      <Dialog open={openDelete} onClose={()=>setOpenDelete(false)} maxWidth="xs" fullWidth>
        <DialogTitle>Eliminar ejercicio</DialogTitle>
        <DialogContent dividers>
          ¿Seguro que deseas eliminar <strong>{toDelete?.nombre}</strong>?
        </DialogContent>
        <DialogActions>
          <Button onClick={()=>setOpenDelete(false)}>Cancelar</Button>
          <Button color="error" variant="contained" onClick={doDelete}>Eliminar</Button>
        </DialogActions>
      </Dialog>

      {/* TOAST */}
      <Snackbar open={toast.open} autoHideDuration={3000}
        onClose={()=>setToast((t)=>({ ...t, open:false }))}
        anchorOrigin={{ vertical:"bottom", horizontal:"right" }}>
        <Alert severity={toast.sev} variant="filled">
          {toast.msg}
        </Alert>
      </Snackbar>

    </Box>
  );
}

export default function PanelEjercicios() {
  return (
    <QueryClientProvider client={queryClient}>
      <PanelEjerciciosInner />
    </QueryClientProvider>
  );
}
