// src/pages/PanelComida.jsx
import React, {
  useCallback,
  useMemo,
  useState,
  useTransition,
  useEffect,
} from "react";
import {
  Box,
  Typography,
  Grid,
  Paper,
  Button,
  TextField,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Accordion,
  AccordionSummary,
  AccordionDetails,
  Chip,
  Pagination,
  Stack,
  Divider,
  IconButton,
  Tooltip,
  Card,
  CardContent,
  Autocomplete,
  Avatar,
} from "@mui/material";
import ExpandMoreIcon from "@mui/icons-material/ExpandMore";
import EditIcon from "@mui/icons-material/Edit";
import DeleteIcon from "@mui/icons-material/Delete";
import AddIcon from "@mui/icons-material/Add";
import FastfoodIcon from "@mui/icons-material/Fastfood";
import RestaurantMenuIcon from "@mui/icons-material/RestaurantMenu";

import {
  QueryClient,
  QueryClientProvider,
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";

import ConfirmDialog from "../components/ConfirmDialog";
import API from "../services/api";

// -------------------- Constantes + utils --------------------
const SIN_TIPO = "Sin tipo";
const MAX_AUTOCOMPLETE_RESULTS = 200;

// detecta si parece un ObjectId (24 hex)
const looksLikeId = (s) => typeof s === "string" && /^[a-f0-9]{24}$/i.test(s);

// filtro limitado (evita coste al escribir)
const limitFilter = (options, { inputValue }) => {
  if (!inputValue) return options.slice(0, MAX_AUTOCOMPLETE_RESULTS);
  const q = inputValue.toLowerCase();
  const out = [];
  for (let i = 0; i < options.length; i++) {
    const v = options[i];
    if (v && v.toLowerCase().includes(q)) {
      out.push(v);
      if (out.length >= MAX_AUTOCOMPLETE_RESULTS) break;
    }
  }
  return out;
};

// -------------------- Subcomponentes memo --------------------
const IngredientesSection = React.memo(function IngredientesSection({
  grouped,
  onEdit,
  onAskDelete,
}) {
  return (
    <Paper elevation={0} sx={{ p: 2.5, borderRadius: 3, border: "1px solid", borderColor: "divider" }}>
      <Stack direction="row" spacing={1} alignItems="center">
        <FastfoodIcon />
        <Typography variant="h6" fontWeight={700}>Ingredientes</Typography>
      </Stack>
      <Divider sx={{ my: 1.5 }} />

      {grouped.map(({ tipo, items }) => (
        <Accordion key={tipo} defaultExpanded={false} disableGutters sx={{ mb: 1 }}>
          <AccordionSummary expandIcon={<ExpandMoreIcon />}>
            <Typography variant="subtitle1" fontWeight={600}>
              {tipo} · {items.length}
            </Typography>
          </AccordionSummary>
          <AccordionDetails>
            <Grid container spacing={2}>
              {items.map((ing) => (
                <Grid item xs={12} sm={6} md={4} key={ing._id}>
                  <Card elevation={0} sx={{ borderRadius: 2, border: "1px solid", borderColor: "divider", height: "100%" }}>
                    <CardContent>
                      <Typography fontWeight={700}>{ing.nombre}</Typography>
                      <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
                        {Math.round(ing.kcal)} kcal · P {ing.proteinas} · C {ing.carbohidratos} · G {ing.grasas}
                      </Typography>
                      <Stack direction="row" spacing={1} justifyContent="flex-end" mt={1}>
                        <Tooltip title="Editar">
                          <IconButton size="small" onClick={() => onEdit(ing)}>
                            <EditIcon fontSize="small" />
                          </IconButton>
                        </Tooltip>
                        <Tooltip title="Eliminar">
                          <IconButton size="small" color="error" onClick={() => onAskDelete(ing)}>
                            <DeleteIcon fontSize="small" />
                          </IconButton>
                        </Tooltip>
                      </Stack>
                    </CardContent>
                  </Card>
                </Grid>
              ))}
            </Grid>
          </AccordionDetails>
        </Accordion>
      ))}
    </Paper>
  );
});

const RecetasSection = React.memo(function RecetasSection({
  recetas,
  pagina,
  setPagina,
  porPagina,
  onEdit,
  onAskDelete,
  getIngName,
}) {
  const totalPages = Math.max(1, Math.ceil((recetas || []).length / porPagina));
  const page = Math.min(pagina, totalPages);
  const start = (page - 1) * porPagina;

  const recetasPaginadas = React.useMemo(
    () => recetas.slice(start, start + porPagina),
    [recetas, start, porPagina]
  );

  return (
    <Paper elevation={0} sx={{ p: 2.5, borderRadius: 3, border: "1px solid", borderColor: "divider" }}>
      <Stack direction="row" spacing={1} alignItems="center">
        <RestaurantMenuIcon />
        <Typography variant="h6" fontWeight={700}>Recetas</Typography>
      </Stack>
      <Divider sx={{ my: 1.5 }} />

      <Box>
        {recetasPaginadas.map((r, i) => (
          <Box key={r._id || r.id || i} sx={{ py: 1.25, borderBottom: "1px dashed", borderColor: "divider" }}>
            <Typography variant="subtitle1" fontWeight={700}>{r.nombre}</Typography>
            <Typography variant="body2" color="text.secondary">
              {Math.round(r.caloriasTotales || 0)} kcal — P {r.macrosTotales?.proteinas ?? 0} · C {r.macrosTotales?.carbohidratos ?? 0} · G {r.macrosTotales?.grasas ?? 0}
            </Typography>

            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap mt={1}>
              {(r.ingredientes || []).map((ing, idx) => (
                <Chip
                  key={idx}
                  size="small"
                  variant="outlined"
                  label={`${getIngName(ing) || "Ingrediente"} (${ing?.gramos ?? 0} g)`}
                />
              ))}
            </Stack>

            <Stack direction="row" spacing={1} justifyContent="flex-end" mt={1}>
              <Tooltip title="Editar">
                <IconButton size="small" onClick={() => onEdit(r)}><EditIcon fontSize="small" /></IconButton>
              </Tooltip>
              <Tooltip title="Eliminar">
                <IconButton size="small" color="error" onClick={() => onAskDelete(r)}><DeleteIcon fontSize="small" /></IconButton>
              </Tooltip>
            </Stack>
          </Box>
        ))}

        <Box mt={2} display="flex" justifyContent="center">
          <Pagination
            count={totalPages}
            page={page}
            onChange={(_, val) => setPagina(val)}
            size="small"
            shape="rounded"
          />
        </Box>
      </Box>
    </Paper>
  );
});

// -------------------- React Query client --------------------
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

// -------------------- Fetchers --------------------
const fetchIngredientes = async ({ signal }) => {
  const res = await API.get("/comidas/ingredientes", { signal });
  return Array.isArray(res.data) ? res.data : [];
};

const fetchRecetas = async ({ signal }) => {
  const res = await API.get("/comidas/recetas", { signal });
  return Array.isArray(res.data) ? res.data : [];
};

// ==================== Página principal ====================
function PanelComidaInner() {
  const qc = useQueryClient();
  const [isPending, startTransition] = useTransition();

  const { data: ingredientes = [] } = useQuery({
    queryKey: ["comidas-ingredientes"],
    queryFn: fetchIngredientes,
  });

  const { data: recetas = [] } = useQuery({
    queryKey: ["comidas-recetas"],
    queryFn: fetchRecetas,
  });

  // Índices O(1)
  const { idToNombre, nombreToId, opcionesIngredientes, groupedIngredientes, tiposIngrediente } = useMemo(() => {
    const idToNombre = new Map();
    const nombreToId = new Map();
    const nombres = [];
    const groupMap = new Map();
        for (const i of ingredientes) {
      if (i?._id) idToNombre.set(i._id, i.nombre || "");
      if (i?.nombre) {
        nombreToId.set(i.nombre, i._id || "");
        nombres.push(i.nombre);
      }
      const t = i?.tipo || SIN_TIPO;
      if (!groupMap.has(t)) groupMap.set(t, []);
      groupMap.get(t).push(i);
    }

    for (const arr of groupMap.values()) {
      arr.sort((a, b) => a.nombre.localeCompare(b.nombre));
    }

    return {
      idToNombre,
      nombreToId,
      opcionesIngredientes: nombres,
      groupedIngredientes: Array.from(groupMap.entries()).map(([tipo, items]) => ({ tipo, items })),
      tiposIngrediente: [...new Set(ingredientes.map((i) => i.tipo || SIN_TIPO))],
    };
  }, [ingredientes]);

  // Helpers O(1)
  const fastResolveId = useCallback((value) => {
    if (!value) return "";
    if (typeof value === "object") return value._id || "";
    if (typeof value === "string") {
      if (looksLikeId(value)) return value;
      return nombreToId.get(value) || "";
    }
    return "";
  }, [nombreToId]);

  const getIngNameFast = useCallback((ing) => {
    if (!ing) return "";
    if (ing.nombre) return ing.nombre;
    if (ing.nombreLibre) return ing.nombreLibre;

    const ref = ing.ingrediente ?? ing.idIngrediente;
    if (!ref) return "";

    if (typeof ref === "object") return ref.nombre || "";
    if (typeof ref === "string") return idToNombre.get(ref) ?? ref;

    return "";
  }, [idToNombre]);

  // -------------------- Estado UI: Ingredientes --------------------
  const [openIngrediente, setOpenIngrediente] = useState(false);
  const [ingredienteEditar, setIngredienteEditar] = useState(null);

  const [nuevoIngrediente, setNuevoIngrediente] = useState({
    nombre: "",
    kcal: "",
    proteinas: "",
    carbohidratos: "",
    grasas: "",
    gramos: 100,
    tipo: "",
  });

  // ---------- VALIDACIÓN: errores ----------
  const [errorsIng, setErrorsIng] = useState({});

  // ---------- VALIDACIÓN PRINCIPAL (nombre + tipo + números) ----------
  const validarIngrediente = useCallback(
    (data) => {
      const err = {};

      const nombreNorm = (data.nombre || "").trim().toLowerCase();
      const tipoNorm = (data.tipo || SIN_TIPO).trim().toLowerCase();

      // Nombre obligatorio
      if (!nombreNorm) {
        err.nombre = "El nombre es obligatorio.";
      }

      // Duplicados (nombre + tipo)
      const existeDuplicado = ingredientes.some((ing) => {
        if (!ing.nombre) return false;

        const nom = ing.nombre.trim().toLowerCase();
        const t = (ing.tipo || SIN_TIPO).trim().toLowerCase();

        // Saltar si es el mismo ingrediente en edición
        if (ingredienteEditar?._id && ing._id === ingredienteEditar._id) return false;

        return nom === nombreNorm && t === tipoNorm;
      });

      if (existeDuplicado) {
        err.nombre = `Ya existe un ingrediente con este nombre en el tipo "${data.tipo || SIN_TIPO}".`;
      }

      // kcal
      if (data.kcal === "" || data.kcal === null) {
        err.kcal = "Las kcal son obligatorias.";
      } else if (Number(data.kcal) < 0) {
        err.kcal = "Debe ser ≥ 0.";
      }

      // proteínas
      if (data.proteinas === "" || data.proteinas === null) {
        err.proteinas = "Las proteínas son obligatorias.";
      } else if (Number(data.proteinas) < 0) {
        err.proteinas = "Debe ser ≥ 0.";
      }

      // carbohidratos
      if (data.carbohidratos === "" || data.carbohidratos === null) {
        err.carbohidratos = "Los carbohidratos son obligatorios.";
      } else if (Number(data.carbohidratos) < 0) {
        err.carbohidratos = "Debe ser ≥ 0.";
      }

      // grasas
      if (data.grasas === "" || data.grasas === null) {
        err.grasas = "Las grasas son obligatorias.";
      } else if (Number(data.grasas) < 0) {
        err.grasas = "Debe ser ≥ 0.";
      }

      return err;
    },
    [ingredientes, ingredienteEditar]
  );

  // Mutations: Ingredientes
  const createIng = useMutation({
    mutationFn: (payload) => API.post("/comidas/ingredientes", payload),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["comidas-ingredientes"] }),
  });

  const updateIng = useMutation({
    mutationFn: ({ id, payload }) => API.put(`/comidas/ingredientes/${id}`, payload),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["comidas-ingredientes"] }),
  });

  const deleteIng = useMutation({
    mutationFn: (id) => API.delete(`/comidas/ingredientes/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["comidas-ingredientes"] }),
  });

  const abrirNuevoIngrediente = useCallback(() => {
    setIngredienteEditar(null);
    setNuevoIngrediente({
      nombre: "",
      kcal: "",
      proteinas: "",
      carbohidratos: "",
      grasas: "",
      gramos: 100,
      tipo: "",
    });
    setErrorsIng({});
    setOpenIngrediente(true);
  }, []);

  const abrirEditarIngrediente = useCallback((ing) => {
    setIngredienteEditar(ing);
    setNuevoIngrediente({
      nombre: ing.nombre || "",
      kcal: ing.kcal ?? "",
      proteinas: ing.proteinas ?? "",
      carbohidratos: ing.carbohidratos ?? "",
      grasas: ing.grasas ?? "",
      gramos: 100,
      tipo: ing.tipo || "",
    });
    setErrorsIng({});
    setOpenIngrediente(true);
  }, []);

  const [confirmOpen, setConfirmOpen] = useState(false);
  const [ingredienteAEliminar, setIngredienteAEliminar] = useState(null);

  const pedirEliminarIngrediente = useCallback((ing) => {
    setIngredienteAEliminar(ing);
    setConfirmOpen(true);
  }, []);

  // ---------- GUARDAR INGREDIENTE ----------
  const guardarIngrediente = useCallback(async () => {
    const data = {
      ...nuevoIngrediente,
      nombre: (nuevoIngrediente.nombre || "").trim(),
    };

    const err = validarIngrediente(data);
    setErrorsIng(err);

    if (Object.keys(err).length > 0) {
      return; // no guardar si hay errores
    }

    if (ingredienteEditar?._id) {
      await updateIng.mutateAsync({ id: ingredienteEditar._id, payload: data });
    } else {
      await createIng.mutateAsync(data);
    }

    setOpenIngrediente(false);
    setIngredienteEditar(null);
    setNuevoIngrediente({
      nombre: "",
      kcal: "",
      proteinas: "",
      carbohidratos: "",
      grasas: "",
      gramos: 100,
      tipo: "",
    });
    setErrorsIng({});
  }, [nuevoIngrediente, ingredienteEditar, validarIngrediente]);

  const handleEliminarIngrediente = useCallback(async () => {
    if (!ingredienteAEliminar?._id) return;
    await deleteIng.mutateAsync(ingredienteAEliminar._id);
    setConfirmOpen(false);
    setIngredienteAEliminar(null);
  }, [ingredienteAEliminar]);

  // -------------------- UI Recetas --------------------
  const [openReceta, setOpenReceta] = useState(false);
  const [modoEditarReceta, setModoEditarReceta] = useState(false);
  const [idRecetaEditando, setIdRecetaEditando] = useState(null);
  const [recetaNombre, setRecetaNombre] = useState("");
  const [recetaLink, setRecetaLink] = useState("");
  const [recetaIngredientes, setRecetaIngredientes] = useState([
    { ingrediente: "", nombreLibre: "", gramos: "" }
  ]);
  const [confirmOpenReceta, setConfirmOpenReceta] = useState(false);
  const [recetaAEliminar, setRecetaAEliminar] = useState(null);
  const [paginaRecetas, setPaginaRecetas] = useState(1);
  const recetasPorPagina = 6;

  const createRec = useMutation({
    mutationFn: (payload) => API.post("/comidas/recetas", payload),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["comidas-recetas"] }),
  });

  const updateRec = useMutation({
    mutationFn: ({ id, payload }) => API.put(`/comidas/recetas/${id}`, payload),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["comidas-recetas"] }),
  });

  const deleteRec = useMutation({
    mutationFn: (id) => API.delete(`/comidas/recetas/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["comidas-recetas"] }),
  });

  const handleEditarReceta = useCallback(
    (receta) => {
      setModoEditarReceta(true);
      setIdRecetaEditando(receta._id || receta.id || null);
      setRecetaNombre(receta.nombre || "");
      setRecetaLink(receta.link || receta.linkPreparacion || "");

      const ingredientesFormateados =
        (receta.ingredientes || []).map((ing) => ({
          ingrediente: ing.ingrediente?._id || ing.ingrediente || "",
          nombreLibre: ing.nombreLibre || "",
          gramos: ing.gramos,
        }));

      setRecetaIngredientes(
        ingredientesFormateados.length
          ? ingredientesFormateados
          : [{ ingrediente: "", nombreLibre: "", gramos: "" }]
      );

      setOpenReceta(true);
    },
    []
  );

  const abrirNuevaReceta = useCallback(() => {
    setModoEditarReceta(false);
    setIdRecetaEditando(null);
    setRecetaNombre("");
    setRecetaLink("");
    setRecetaIngredientes([{ ingrediente: "", nombreLibre: "", gramos: "" }]);
    setOpenReceta(true);
  }, []);

    // Guardar receta
  const guardarReceta = useCallback(async () => {
    const ingredientesNorm = recetaIngredientes
      .map((x) => {
        const gramos = Number(x.gramos || 0);
        if (x.ingrediente) {
          return { ingrediente: x.ingrediente, gramos };
        }
        if (x.nombreLibre && x.nombreLibre.trim()) {
          return { nombreLibre: x.nombreLibre.trim(), gramos };
        }
        return null;
      })
      .filter(Boolean);

    const payload = {
      nombre: recetaNombre.trim(),
      link: recetaLink.trim(),
      ingredientes: ingredientesNorm,
    };

    if (!payload.nombre) return;

    if (modoEditarReceta && idRecetaEditando) {
      await updateRec.mutateAsync({ id: idRecetaEditando, payload });
    } else {
      await createRec.mutateAsync(payload);
    }

    setOpenReceta(false);
    setModoEditarReceta(false);
    setIdRecetaEditando(null);
    setRecetaNombre("");
    setRecetaLink("");
    setRecetaIngredientes([{ ingrediente: "", nombreLibre: "", gramos: "" }]);
  }, [
    recetaIngredientes,
    recetaNombre,
    recetaLink,
    modoEditarReceta,
    idRecetaEditando,
    updateRec,
    createRec,
  ]);

  const pedirEliminarReceta = useCallback((receta) => {
    setRecetaAEliminar(receta);
    setConfirmOpenReceta(true);
  }, []);

  const handleEliminarReceta = useCallback(async () => {
    if (!recetaAEliminar) return;
    await deleteRec.mutateAsync(recetaAEliminar._id || recetaAEliminar.id);
    setConfirmOpenReceta(false);
    setRecetaAEliminar(null);
  }, [recetaAEliminar, deleteRec]);

  // ---------- Render ----------
  return (
    <Box p={{ xs: 2, md: 4 }}>
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
            "linear-gradient(180deg, rgba(246,247,251,0.7) 0%, rgba(255,255,255,1) 45%)",
        }}
      >
        <Stack
          direction={{ xs: "column", md: "row" }}
          alignItems={{ xs: "flex-start", md: "center" }}
          justifyContent="space-between"
          spacing={2}
        >
          <Stack direction="row" spacing={1.2} alignItems="center">
            <Avatar sx={{ width: 36, height: 36 }}>
              <FastfoodIcon color="primary" />
            </Avatar>
            <Typography variant="h5" fontWeight={800}>
              Panel de Comidas
            </Typography>
          </Stack>

          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
            <Button
              startIcon={<AddIcon />}
              variant="outlined"
              onClick={abrirNuevoIngrediente}
              sx={{ textTransform: "none", borderRadius: 2 }}
            >
              Nuevo ingrediente
            </Button>
            <Button
              startIcon={<RestaurantMenuIcon />}
              variant="contained"
              onClick={abrirNuevaReceta}
              sx={{ textTransform: "none", borderRadius: 2 }}
            >
              Nueva receta
            </Button>
          </Stack>
        </Stack>
      </Paper>

      <Grid container spacing={3}>
        {/* Ingredientes */}
        <Grid item xs={12} md={8}>
          <IngredientesSection
            grouped={groupedIngredientes}
            onEdit={abrirEditarIngrediente}
            onAskDelete={pedirEliminarIngrediente}
          />
        </Grid>

        {/* Recetas */}
        <Grid item xs={12} md={4}>
          <RecetasSection
            recetas={recetas}
            pagina={paginaRecetas}
            setPagina={setPaginaRecetas}
            porPagina={recetasPorPagina}
            onEdit={handleEditarReceta}
            onAskDelete={pedirEliminarReceta}
            getIngName={getIngNameFast}
          />
        </Grid>
      </Grid>

      {/* Dialog: Nuevo/Editar Ingrediente */}
      <Dialog
        open={openIngrediente}
        onClose={() => setOpenIngrediente(false)}
        maxWidth="xs"
        fullWidth
        keepMounted
      >
        <DialogTitle>
          {ingredienteEditar ? "Editar ingrediente" : "Nuevo ingrediente"}
        </DialogTitle>

        <DialogContent>
          <TextField
            label="Gramos (base)"
            fullWidth
            margin="dense"
            value={100}
            disabled
          />

          <TextField
            label="Nombre"
            fullWidth
            margin="dense"
            value={nuevoIngrediente.nombre}
            error={!!errorsIng.nombre}
            helperText={errorsIng.nombre}
            onChange={(e) =>
              setNuevoIngrediente((prev) => ({
                ...prev,
                nombre: e.target.value,
              }))
            }
          />

          <TextField
            label="Kcal"
            fullWidth
            type="number"
            margin="dense"
            value={nuevoIngrediente.kcal}
            error={!!errorsIng.kcal}
            helperText={errorsIng.kcal}
            onChange={(e) =>
              setNuevoIngrediente((prev) => ({
                ...prev,
                kcal: e.target.value,
              }))
            }
          />

          <TextField
            label="Proteínas"
            fullWidth
            type="number"
            margin="dense"
            value={nuevoIngrediente.proteinas}
            error={!!errorsIng.proteinas}
            helperText={errorsIng.proteinas}
            onChange={(e) =>
              setNuevoIngrediente((prev) => ({
                ...prev,
                proteinas: e.target.value,
              }))
            }
          />

          <TextField
            label="Carbohidratos"
            fullWidth
            type="number"
            margin="dense"
            value={nuevoIngrediente.carbohidratos}
            error={!!errorsIng.carbohidratos}
            helperText={errorsIng.carbohidratos}
            onChange={(e) =>
              setNuevoIngrediente((prev) => ({
                ...prev,
                carbohidratos: e.target.value,
              }))
            }
          />

          <TextField
            label="Grasas"
            fullWidth
            type="number"
            margin="dense"
            value={nuevoIngrediente.grasas}
            error={!!errorsIng.grasas}
            helperText={errorsIng.grasas}
            onChange={(e) =>
              setNuevoIngrediente((prev) => ({
                ...prev,
                grasas: e.target.value,
              }))
            }
          />

          <Autocomplete
            freeSolo
            options={tiposIngrediente}
            filterOptions={limitFilter}
            value={nuevoIngrediente.tipo || ""}
            onChange={(_, val) =>
              setNuevoIngrediente((prev) => ({
                ...prev,
                tipo: typeof val === "string" ? val : val || "",
              }))
            }
            onInputChange={(_, val) =>
              setNuevoIngrediente((prev) => ({ ...prev, tipo: val }))
            }
            renderInput={(params) => (
              <TextField {...params} label="Tipo" margin="dense" size="small" />
            )}
          />
        </DialogContent>

        <DialogActions>
          <Button
            onClick={() => {
              setOpenIngrediente(false);
              setIngredienteEditar(null);
            }}
          >
            Cancelar
          </Button>

          <Button
            onClick={guardarIngrediente}
            variant="contained"
            disabled={createIng.isPending || updateIng.isPending}
          >
            Guardar
          </Button>
        </DialogActions>
      </Dialog>

      {/* Dialog: Nueva/Editar Receta */}
      <Dialog
        open={openReceta}
        onClose={() => setOpenReceta(false)}
        maxWidth="sm"
        fullWidth
        keepMounted
      >
        <DialogTitle>
          {modoEditarReceta ? "Editar receta" : "Nueva receta"}
        </DialogTitle>

        <DialogContent>
          <TextField
            label="Nombre"
            fullWidth
            margin="dense"
            value={recetaNombre}
            onChange={(e) => setRecetaNombre(e.target.value)}
          />

          <TextField
            label="Link preparación"
            fullWidth
            margin="dense"
            value={recetaLink}
            onChange={(e) => setRecetaLink(e.target.value)}
          />

          <Divider sx={{ my: 1.5 }} />
          <Typography variant="subtitle2" sx={{ mb: 1 }}>
            Ingredientes
          </Typography>

          {recetaIngredientes.map((item, index) => (
            <Grid
              container
              spacing={1}
              key={index}
              alignItems="center"
              sx={{ mb: 1 }}
            >
              <Grid item xs={7}>
                <Autocomplete
                  disablePortal
                  freeSolo
                  options={opcionesIngredientes}
                  filterOptions={limitFilter}
                  value={
                    idToNombre.get(item.ingrediente) ||
                    item.nombreLibre ||
                    ""
                  }
                  onChange={(_, val) => {
                    startTransition(() => {
                      setRecetaIngredientes((list) => {
                        const updated = [...list];
                        if (!val) {
                          updated[index] = {
                            ...updated[index],
                            ingrediente: "",
                            nombreLibre: "",
                          };
                        } else {
                          const id = nombreToId.get(String(val));
                          updated[index] = id
                            ? { ...updated[index], ingrediente: id, nombreLibre: "" }
                            : { ...updated[index], ingrediente: "", nombreLibre: String(val) };
                        }
                        return updated;
                      });
                    });
                  }}
                  renderInput={(params) => (
                    <TextField {...params} label="Ingrediente" size="small" />
                  )}
                />
              </Grid>

              <Grid item xs={3}>
                <TextField
                  size="small"
                  label="Gramos"
                  fullWidth
                  type="number"
                  inputProps={{ min: 0 }}
                  value={item.gramos ?? ""}
                  onChange={(e) => {
                    const val = e.target.value;
                    setRecetaIngredientes((list) => {
                      const updated = [...list];
                      updated[index] = { ...updated[index], gramos: val };
                      return updated;
                    });
                  }}
                />
              </Grid>

              <Grid item xs={2} sx={{ textAlign: "right" }}>
                <Tooltip title="Quitar">
                  <IconButton
                    color="error"
                    onClick={() =>
                      setRecetaIngredientes((list) =>
                        list.filter((_, i) => i !== index)
                      )
                    }
                    size="small"
                  >
                    <DeleteIcon fontSize="small" />
                  </IconButton>
                </Tooltip>
              </Grid>
            </Grid>
          ))}

          <Button
            startIcon={<AddIcon />}
            onClick={() =>
              setRecetaIngredientes((prev) => [
                ...prev,
                { ingrediente: "", nombreLibre: "", gramos: "" },
              ])
            }
          >
            Añadir ingrediente
          </Button>
        </DialogContent>

        <DialogActions>
          <Button
            onClick={() => {
              setOpenReceta(false);
              setModoEditarReceta(false);
              setRecetaNombre("");
              setRecetaLink("");
              setRecetaIngredientes([
                { ingrediente: "", nombreLibre: "", gramos: "" },
              ]);
            }}
          >
            Cancelar
          </Button>

          <Button
            onClick={guardarReceta}
            variant="contained"
            disabled={createRec.isPending || updateRec.isPending || isPending}
          >
            {modoEditarReceta ? "Actualizar" : "Guardar"}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Confirm eliminar ingrediente */}
      <ConfirmDialog
        open={confirmOpen}
        title="Eliminar Ingrediente"
        message="¿Seguro que quieres eliminar este ingrediente?"
        onConfirm={handleEliminarIngrediente}
        onCancel={() => setConfirmOpen(false)}
      />

      {/* Confirm eliminar receta */}
      <ConfirmDialog
        open={confirmOpenReceta}
        title="Eliminar Receta"
        message={`¿Seguro que quieres eliminar la receta "${recetaAEliminar?.nombre}"?`}
        onConfirm={handleEliminarReceta}
        onCancel={() => setConfirmOpenReceta(false)}
      />
    </Box>
  );
}

// Export
export default function PanelComida() {
  return (
    <QueryClientProvider client={queryClient}>
      <PanelComidaInner />
    </QueryClientProvider>
  );
}

