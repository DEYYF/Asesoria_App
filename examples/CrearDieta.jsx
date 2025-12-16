// src/pages/CrearDieta.jsx
import { useEffect, useMemo, useState } from "react";
import {
  Box,
  Stack,
  Grid,
  Paper,
  Typography,
  TextField,
  Tabs,
  Tab,
  Button,
  Chip,
  IconButton,
  Divider,
  Autocomplete,
  Tooltip,
  List,
  ListItem,
  ListItemText,
  ToggleButton,
  ToggleButtonGroup,
  Alert,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogContentText,
  DialogActions,
  Snackbar,
} from "@mui/material";
import { useParams, useNavigate } from "react-router-dom";
import AddIcon from "@mui/icons-material/Add";
import DeleteOutlineIcon from "@mui/icons-material/DeleteOutline";
import RestaurantMenuIcon from "@mui/icons-material/RestaurantMenu";
import LocalDiningIcon from "@mui/icons-material/LocalDining";
import EmojiFoodBeverageIcon from "@mui/icons-material/EmojiFoodBeverage";
import PlaylistAddIcon from "@mui/icons-material/PlaylistAdd";
import API from "../services/api";
import { useAuth } from "../context/AuthContext";
import { extractAsesorId } from "../utils/auth";


// ----------------- Helpers -----------------
const ZERO = { kcal: 0, proteinas: 0, carbohidratos: 0, grasas: 0 };
const getId = (o) => o?._id || o?.id || null;
const fmt = (n, d = 0) =>
  typeof n === "number" ? Number(n.toFixed(d)).toLocaleString() : n ?? "-";

const scale = (per100, gramos) => {
  const f = (Number(gramos) || 0) / 100;
  return {
    kcal: +(f * (per100?.kcal || 0)).toFixed(2),
    proteinas: +(f * (per100?.proteinas || 0)).toFixed(2),
    carbohidratos: +(f * (per100?.carbohidratos || 0)).toFixed(2),
    grasas: +(f * (per100?.grasas || 0)).toFixed(2),
  };
};
const add = (a, b) => ({
  kcal: +(a.kcal + (b?.kcal || 0)).toFixed(2),
  proteinas: +(a.proteinas + (b?.proteinas || 0)).toFixed(2),
  carbohidratos: +(a.carbohidratos + (b?.carbohidratos || 0)).toFixed(2),
  grasas: +(a.grasas + (b?.grasas || 0)).toFixed(2),
});
const divide = (a, k) => {
  const d = Number(k) || 1;
  return {
    kcal: +((a.kcal || 0) / d).toFixed(2),
    proteinas: +((a.proteinas || 0) / d).toFixed(2),
    carbohidratos: +((a.carbohidratos || 0) / d).toFixed(2),
    grasas: +((a.grasas || 0) / d).toFixed(2),
  };
};
const mealPresetNames = (n) => {
  switch (Number(n)) {
    case 2:
      return ["Comida", "Cena"];
    case 3:
      return ["Desayuno", "Comida", "Cena"];
    case 4:
      return ["Desayuno", "Comida", "Merienda", "Cena"];
    case 5:
      return ["Desayuno", "Almuerzo", "Comida", "Merienda", "Cena"];
    default:
      return ["Desayuno", "Comida", "Cena"];
  }
};

// ----------------- Página -----------------
const CrearDieta = () => {
  const { clienteId } = useParams(); // viene en la ruta
  const navigate = useNavigate();

  // Lee asesorId correctamente desde localStorage (solo _id)
  const { user, token } = useAuth();
  const asesorId = useMemo(() => extractAsesorId(user, token), [user, token]);

  // Objetivos
  const [objetivoInput, setObjetivoInput] = useState("");
  const [objetivos, setObjetivos] = useState([]);

  // Comidas y editor
  const [comidas, setComidas] = useState([]); // se inicializa con "Aplicar plantilla"
  const [activeComida, setActiveComida] = useState(0);
  const [tab, setTab] = useState(0); // 0 Receta, 1 Alimento, 2 Combinación

  // Paso previo: nº de comidas
  const [mealCount, setMealCount] = useState(3);
  const [showOverwriteConfirm, setShowOverwriteConfirm] = useState(false);
  const hasContent = comidas.some((c) => (c.opciones || []).length > 0);

  const initComidas = (n) => {
    const names = mealPresetNames(n);
    setComidas(names.map((nombre) => ({ nombre, opciones: [] })));
    setActiveComida(0);
  };
  const applyTemplate = () => {
    if (hasContent) setShowOverwriteConfirm(true);
    else initComidas(mealCount);
  };

  // Data from API
  const [recetasAll, setRecetasAll] = useState([]);
  const [ingredientesAll, setIngredientesAll] = useState([]);
  const [qReceta, setQReceta] = useState("");
  const [qIng, setQIng] = useState("");

  useEffect(() => {
    // GET /comidas/recetas
    API.get("/comidas/recetas")
      .then((r) => setRecetasAll(r.data || []))
      .catch((e) => console.error("recetas:", e));
    // GET /comidas/ingredientes
    API.get("/comidas/ingredientes")
      .then((r) => setIngredientesAll(r.data || []))
      .catch((e) => console.error("ingredientes:", e));
  }, []);

  const recetas = useMemo(() => {
    const q = qReceta.trim().toLowerCase();
    if (!q) return recetasAll;
    if (!q) return recetasAll;
    return recetasAll.filter((r) =>
      (r?.nombre || "").toLowerCase().includes(q)
    );
  }, [recetasAll, qReceta]);

  // Validaciones
  const [errorMsg, setErrorMsg] = useState("");
  const [openError, setOpenError] = useState(false);
  const notifyError = (msg) => {
    setErrorMsg(msg);
    setOpenError(true);
  };

  const ingredientes = useMemo(() => {
    const q = qIng.trim().toLowerCase();
    if (!q) return ingredientesAll;
    return ingredientesAll.filter((i) =>
      (i?.nombre || "").toLowerCase().includes(q)
    );
  }, [ingredientesAll, qIng]);

  const ingById = useMemo(
    () => new Map(ingredientesAll.map((i) => [getId(i), i])),
    [ingredientesAll]
  );

  // Selecciones
  const [recetaSel, setRecetaSel] = useState(null);
  const [aliSel, setAliSel] = useState(null);
  const [aliGr, setAliGr] = useState("");
  // Combinación (usa alimentos: [{ ingredienteId, gramos, ingrediente? }])
  const [combAlimentos, setCombAlimentos] = useState([]);
  const [combIngSel, setCombIngSel] = useState(null);
  const [combGr, setCombGr] = useState("");

  // Totales de una opción (para medias y sumas)
  const totalsForOption = (op) => {
    if (!op) return { ...ZERO };
    if (op.tipo === "Receta" && op.receta) {
      return {
        kcal: op.receta.caloriasTotales || 0,
        proteinas: op.receta.macrosTotales?.proteinas || 0,
        carbohidratos: op.receta.macrosTotales?.carbohidratos || 0,
        grasas: op.receta.macrosTotales?.grasas || 0,
      };
    }
    if (op.tipo === "Alimento" && op.ingrediente) {
      return scale(op.ingrediente, op.gramos || 0);
    }
    if (op.tipo === "Combinacion") {
      return (op.alimentos || []).reduce(
        (acc, it) => {
          const det = it.ingrediente || ingById.get(it.ingredienteId);
          return add(acc, scale(det, it.gramos || 0));
        },
        { ...ZERO }
      );
    }
    return { ...ZERO };
  };

  // Totales si comieras todas las opciones
  const totalesPorComida = useMemo(() => {
    return comidas.map((c) =>
      (c.opciones || [])
        .map(totalsForOption)
        .reduce((acc, cur) => add(acc, cur), { ...ZERO })
    );
  }, [comidas, ingById]);

  // Media por comida (promedio entre opciones)
  const mediasPorComida = useMemo(() => {
    return comidas.map((c) => {
      const ops = c.opciones || [];
      if (!ops.length) return { ...ZERO };
      const sum = ops
        .map(totalsForOption)
        .reduce((a, b) => add(a, b), { ...ZERO });
      return divide(sum, ops.length);
    });
  }, [comidas, ingById]);

  // Globales
  const totalesGlobal = useMemo(
    () => totalesPorComida.reduce((acc, t) => add(acc, t), { ...ZERO }),
    [totalesPorComida]
  );
  const totalEstimado = useMemo(
    () => mediasPorComida.reduce((acc, t) => add(acc, t), { ...ZERO }),
    [mediasPorComida]
  );

  // Añadir opciones a la comida activa
  const pushOpcion = (op) => {
    if (!comidas.length) return;
    setComidas((prev) => {
      const next = [...prev];
      next[activeComida] = {
        ...next[activeComida],
        opciones: [...(next[activeComida].opciones || []), op],
      };
      return next;
    });
  };

  // RECETA
  const handleAddReceta = () => {
    if (!recetaSel) {
        notifyError("Por favor, selecciona una receta.");
        return;
    }
    pushOpcion({ tipo: "Receta", receta: recetaSel });
    setRecetaSel(null);
    setQReceta("");
  };

  // ALIMENTO
  const handleAddAlimento = () => {
    if (!aliSel) {
        notifyError("Por favor, selecciona un ingrediente.");
        return;
    }
    const gramos = Number(aliGr);
    if (!aliGr || !Number.isFinite(gramos) || gramos <= 0) {
        notifyError("Los gramos deben ser mayor a 0.");
        return;
    }
    pushOpcion({ tipo: "Alimento", ingrediente: aliSel, gramos });
    setAliSel(null);
    setAliGr("");
    setQIng("");
  };

  /* New: Custom name for combination */
  const [combCustomName, setCombCustomName] = useState("");

  // COMBINACIÓN (alimentos)
  const addCombItem = () => {
    if (!combIngSel) {
        notifyError("Por favor, selecciona un ingrediente.");
        return;
    }
    const gramos = Number(combGr);
    if (!combGr || !Number.isFinite(gramos) || gramos <= 0) {
         notifyError("Los gramos deben ser mayor a 0.");
         return;
    }
    setCombAlimentos((prev) => [
      ...prev,
      {
        ingredienteId: getId(combIngSel),
        gramos,
        ingrediente: combIngSel, // cache para UI/cálculos
      },
    ]);
    setCombIngSel(null);
    setCombGr("");
    setQIng("");
  };

  const addCombinationToMeal = () => {
    if (combAlimentos.length === 0) return;
    
    // Use custom name if provided, otherwise auto-generate
    const nombre = combCustomName.trim() || combAlimentos
      .map(
        (it) => it?.ingrediente?.nombre || ingById.get(it.ingredienteId)?.nombre
      )
      .filter(Boolean)
      .join(" + ");

    pushOpcion({ tipo: "Combinacion", nombre, alimentos: combAlimentos });
    setCombAlimentos([]);
    setCombCustomName("");
  };

  // Quitar opción
  const removeOpcion = (idx) => {
    setComidas((prev) => {
      const next = [...prev];
      next[activeComida] = {
        ...next[activeComida],
        opciones: (next[activeComida].opciones || []).filter(
          (_, i) => i !== idx
        ),
      };
      return next;
    });
  };

  // Añadir / renombrar comidas
  const addComida = () =>
    setComidas((p) => [
      ...p,
      { nombre: `Comida ${p.length + 1}`, opciones: [] },
    ]);

  const setNombreComida = (i, nombre) => {
    setComidas((prev) => {
      const next = [...prev];
      next[i] = { ...next[i], nombre };
      return next;
    });
  };

    // Guardar dieta
    // Guardar dieta (nuevo esquema)
const handleGuardar = async () => {
  if (!asesorId) {
    alert("No se pudo identificar al asesor. Inicia sesión de nuevo, por favor.");
    return;
  }
  if (!clienteId) {
    alert("Falta el clienteId en la URL.");
    return;
  }

  const payload = {
    clienteId: String(clienteId),
    asesorId: String(asesorId),

    // campos básicos
    nombre: "Dieta",
    objetivo: "salud",
    estado: "borrador",
    notas: "",

    // macros del NUEVO backend
    macros: {
      kcal: Number(totalEstimado.kcal) || 0,
      p: Number(totalEstimado.proteinas) || 0,
      c: Number(totalEstimado.carbohidratos) || 0,
      g: Number(totalEstimado.grasas) || 0,
    },

    // comidas + opciones (mapeo a nuevo formato)
    comidas: (comidas || []).map((c) => ({
      titulo: (c?.nombre || "").trim() || "Comida",
      hora: c?.hora || undefined,
      notas: c?.notas || "",
      opciones: (c?.opciones || []).map((op) => {
        const tipo = (op?.tipo || "").toString().toLowerCase();

        if (tipo === "receta") {
          return {
            tipo: "receta",
            recetaId: String(getId(op.receta)),
            nombre: op?.receta?.nombre || undefined, // snapshot opcional
          };
        }

        if (tipo === "alimento" || tipo === "ingrediente") {
          return {
            tipo: "ingrediente",
            ingredienteId: String(getId(op.ingrediente)),
            nombre: op?.ingrediente?.nombre || undefined, // snapshot opcional
            gramos: Number(op?.gramos) || 0,
            unidades: typeof op?.unidades === "number" ? op.unidades : undefined,
          };
        }

        // combinacion (array de alimentos -> items[])
        const arr = op?.alimentos || op?.items || [];
        return {
          tipo: "combinacion",
          nombre: op.nombre || undefined, // PERSIST CUSTOM NAME
          items: arr
            .filter((it) => (it.ingredienteId || getId(it.ingrediente)) && Number(it.gramos) > 0)
            .map((it) => ({
              ingredienteId: String(it.ingredienteId || getId(it.ingrediente)),
              nombre:
                it?.ingrediente?.nombre /* snapshot opcional */ || undefined,
              gramos: Number(it.gramos) || 0,
            })),
          notas: op?.notas || "",
        };
      }),
    })),
  };

  try {
    // POST crea la rev=1 ya con el nuevo formato
    const res = await API.post("/dietas", payload);
    navigate(`/dieta/${res.data._id}`);
  } catch (e) {
    console.error("Error guardando dieta", e);
    alert(
      e?.response?.data?.error
        ? `No se pudo guardar la dieta: ${e.response.data.error}`
        : "No se pudo guardar la dieta."
    );
  }
};


  // ----------------- UI -----------------
  const objetivoChip = (o, i) => (
    <Chip
      key={i}
      label={o}
      onDelete={() => setObjetivos((p) => p.filter((_, idx) => idx !== i))}
      sx={{ borderRadius: 2 }}
    />
  );

  const hasMeals = comidas.length > 0;

  return (
    <Box p={{ xs: 2, md: 4 }}>
      <Stack
        direction={{ xs: "column", md: "row" }}
        spacing={2}
        alignItems={{ md: "center" }}
        justifyContent="space-between"
        mb={2}
      >
        <Typography variant="h4" fontWeight={800}>
          Crear dieta
        </Typography>
        <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
          <Button variant="outlined" onClick={() => navigate(-1)}>
            Volver
          </Button>
          <Button
            variant="contained"
            onClick={handleGuardar}
            disabled={!hasMeals}
          >
            Guardar dieta
          </Button>
        </Stack>
      </Stack>

      {/* PASO 0: Elegir nº de comidas */}
      <Paper variant="outlined" sx={{ p: 2, mb: 2, borderRadius: 2 }}>
        <Typography variant="h6" fontWeight={700} gutterBottom>
          Número de comidas
        </Typography>
        <Stack
          direction={{ xs: "column", sm: "row" }}
          spacing={2}
          alignItems={{ sm: "center" }}
        >
          <ToggleButtonGroup
            color="primary"
            exclusive
            value={mealCount}
            onChange={(_, v) => {
              if (v) setMealCount(v);
            }}
            size="small"
          >
            <ToggleButton value={2}>2</ToggleButton>
            <ToggleButton value={3}>3</ToggleButton>
            <ToggleButton value={4}>4</ToggleButton>
            <ToggleButton value={5}>5</ToggleButton>
          </ToggleButtonGroup>

          <Stack
            direction="row"
            spacing={1}
            flexWrap="wrap"
            useFlexGap
            alignItems="center"
          >
            {mealPresetNames(mealCount).map((n, i) => (
              <Chip key={i} label={n} size="small" sx={{ borderRadius: 2 }} />
            ))}
          </Stack>

          <Button variant="contained" onClick={applyTemplate}>
            Aplicar plantilla
          </Button>
        </Stack>
        {hasContent && (
          <Alert severity="warning" sx={{ mt: 1 }}>
            Reaplicar la plantilla <strong>reiniciará</strong> las comidas
            (perderás las opciones añadidas).
          </Alert>
        )}
      </Paper>

      {/* Confirmación al replantillar */}
      <Dialog
        open={showOverwriteConfirm}
        onClose={() => setShowOverwriteConfirm(false)}
      >
        <DialogTitle>Reemplazar comidas</DialogTitle>
        <DialogContent>
          <DialogContentText>
            Se perderán las opciones ya añadidas. ¿Aplicar plantilla de{" "}
            {mealCount} comidas?
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setShowOverwriteConfirm(false)}>
            Cancelar
          </Button>
          <Button
            color="error"
            variant="contained"
            onClick={() => {
              initComidas(mealCount);
              setShowOverwriteConfirm(false);
            }}
          >
            Aplicar
          </Button>
        </DialogActions>
      </Dialog>

      {/* Objetivos */}
      <Paper variant="outlined" sx={{ p: 2, mb: 2, borderRadius: 2 }}>
        <Typography variant="h6" fontWeight={700} gutterBottom>
          Objetivos
        </Typography>
        <Stack direction="row" spacing={1} alignItems="center">
          <TextField
            size="small"
            label="Añadir objetivo"
            value={objetivoInput}
            onChange={(e) => setObjetivoInput(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter" && objetivoInput.trim()) {
                setObjetivos((p) => [...p, objetivoInput.trim()]);
                setObjetivoInput("");
              }
            }}
          />
          <Button
            startIcon={<AddIcon />}
            variant="outlined"
            onClick={() => {
              if (objetivoInput.trim()) {
                setObjetivos((p) => [...p, objetivoInput.trim()]);
                setObjetivoInput("");
              }
            }}
          >
            Añadir
          </Button>
        </Stack>
        <Stack direction="row" spacing={1} mt={1} flexWrap="wrap" useFlexGap>
          {objetivos.map(objetivoChip)}
        </Stack>
      </Paper>

      <Grid container spacing={2}>
        {/* Creador / Menú */}
        <Grid item xs={12} md={7} lg={8}>
          <Paper variant="outlined" sx={{ p: 2, borderRadius: 2, mb: 2 }}>
            <Stack
              direction={{ xs: "column", sm: "row" }}
              spacing={2}
              alignItems={{ sm: "center" }}
            >
              {/* Selector de comida */}
              <Autocomplete
                sx={{ minWidth: 220 }}
                options={comidas.map((c, i) => ({ label: c.nombre, value: i }))}
                value={
                  hasMeals
                    ? {
                        label: comidas[activeComida]?.nombre,
                        value: activeComida,
                      }
                    : null
                }
                onChange={(_, v) => setActiveComida(v?.value ?? 0)}
                renderInput={(params) => (
                  <TextField
                    {...params}
                    label="Selecciona comida"
                    size="small"
                  />
                )}
                disabled={!hasMeals}
              />
              <TextField
                size="small"
                label="Renombrar comida"
                value={comidas[activeComida]?.nombre || ""}
                onChange={(e) => setNombreComida(activeComida, e.target.value)}
                disabled={!hasMeals}
              />
              <Button
                startIcon={<PlaylistAddIcon />}
                onClick={addComida}
                disabled={!hasMeals}
              >
                Añadir comida
              </Button>
            </Stack>

            <Tabs value={tab} onChange={(_, v) => setTab(v)} sx={{ mt: 2 }}>
              <Tab
                icon={<RestaurantMenuIcon sx={{ mr: 1 }} />}
                iconPosition="start"
                label="Receta"
              />
              <Tab
                icon={<LocalDiningIcon sx={{ mr: 1 }} />}
                iconPosition="start"
                label="Alimento"
              />
              <Tab
                icon={<EmojiFoodBeverageIcon sx={{ mr: 1 }} />}
                iconPosition="start"
                label="Combinación"
              />
            </Tabs>

            {/* --- RECETA --- */}
            {tab === 0 && (
              <Box mt={2}>
                <Autocomplete
                  options={recetas}
                  getOptionLabel={(o) => o?.nombre || ""}
                  onInputChange={(_, v) => setQReceta(v)}
                  value={recetaSel}
                  onChange={(_, v) => setRecetaSel(v)}
                  renderInput={(params) => (
                    <TextField
                      {...params}
                      label="Buscar receta"
                      size="small"
                      placeholder="Ej. tortitas, boloñesa..."
                    />
                  )}
                  disabled={!hasMeals}
                />
                {recetaSel && (
                  <Box mt={1} sx={{ color: "text.secondary" }}>
                    <Typography variant="body2">
                      kcal: <b>{fmt(recetaSel.caloriasTotales, 0)}</b> · P:{" "}
                      <b>{fmt(recetaSel.macrosTotales?.proteinas, 1)}</b> · C:{" "}
                      <b>{fmt(recetaSel.macrosTotales?.carbohidratos, 1)}</b> ·
                      G: <b>{fmt(recetaSel.macrosTotales?.grasas, 1)}</b>
                    </Typography>
                  </Box>
                )}
                <Button
                  sx={{ mt: 1.5 }}
                  variant="contained"
                  onClick={handleAddReceta}
                  disabled={!recetaSel || !hasMeals}
                >
                  Añadir receta a {comidas[activeComida]?.nombre || "—"}
                </Button>
              </Box>
            )}

            {/* --- ALIMENTO --- */}
            {tab === 1 && (
              <Box mt={2}>
                <Stack direction={{ xs: "column", sm: "row" }} spacing={1.5}>
                  <Autocomplete
                    sx={{ flex: 1 }}
                    options={ingredientes}
                    getOptionLabel={(o) => o?.nombre || ""}
                    onInputChange={(_, v) => setQIng(v)}
                    value={aliSel}
                    onChange={(_, v) => setAliSel(v)}
                    renderInput={(params) => (
                      <TextField
                        {...params}
                        label="Buscar ingrediente"
                        size="small"
                      />
                    )}
                    disabled={!hasMeals}
                  />
                  <TextField
                    label="Gramos"
                    size="small"
                    type="number"
                    value={aliGr}
                    onChange={(e) => setAliGr(e.target.value)}
                    sx={{ width: 140 }}
                    inputProps={{ min: 0 }}
                    disabled={!hasMeals}
                  />
                </Stack>

                {aliSel && aliGr && Number(aliGr) > 0 && (
                  <Typography
                    variant="body2"
                    sx={{ mt: 1, color: "text.secondary" }}
                  >
                    Añade: kcal{" "}
                    <b>{fmt(scale(aliSel, Number(aliGr)).kcal, 0)}</b> · P{" "}
                    <b>{fmt(scale(aliSel, Number(aliGr)).proteinas, 1)}</b> · C{" "}
                    <b>{fmt(scale(aliSel, Number(aliGr)).carbohidratos, 1)}</b>{" "}
                    · G <b>{fmt(scale(aliSel, Number(aliGr)).grasas, 1)}</b>
                  </Typography>
                )}

                <Button
                  sx={{ mt: 1.5 }}
                  variant="contained"
                  onClick={handleAddAlimento}
                  disabled={!aliSel || !aliGr || !hasMeals}
                >
                  Añadir alimento a {comidas[activeComida]?.nombre || "—"}
                </Button>
              </Box>
            )}

            {/* --- COMBINACIÓN --- */}
            {tab === 2 && (
              <Box mt={2}>
                <Stack direction={{ xs: "column", sm: "row" }} spacing={1.5}>
                  <Autocomplete
                    sx={{ flex: 1 }}
                    options={ingredientes}
                    getOptionLabel={(o) => o?.nombre || ""}
                    onInputChange={(_, v) => setQIng(v)}
                    value={combIngSel}
                    onChange={(_, v) => setCombIngSel(v)}
                    renderInput={(params) => (
                      <TextField
                        {...params}
                        label="Buscar ingrediente"
                        size="small"
                      />
                    )}
                    disabled={!hasMeals}
                  />
                  <TextField
                    label="Gramos"
                    size="small"
                    type="number"
                    value={combGr}
                    onChange={(e) => setCombGr(e.target.value)}
                    sx={{ width: 140 }}
                    inputProps={{ min: 0 }}
                    disabled={!hasMeals}
                  />
                  <Button
                    variant="outlined"
                    onClick={addCombItem}
                    startIcon={<AddIcon />}
                    disabled={!hasMeals}
                  >
                    Añadir a combinación
                  </Button>
                </Stack>

                <List dense sx={{ mt: 1 }}>
                  {(combAlimentos || []).map((it, idx) => (
                    <ListItem
                      key={idx}
                      secondaryAction={
                        <IconButton
                          edge="end"
                          onClick={() =>
                            setCombAlimentos((p) =>
                              p.filter((_, i) => i !== idx)
                            )
                          }
                        >
                          <DeleteOutlineIcon />
                        </IconButton>
                      }
                    >
                      <ListItemText
                        primary={
                          it?.ingrediente?.nombre ||
                          ingById.get(it.ingredienteId)?.nombre ||
                          "-"
                        }
                        secondary={`${it?.gramos || 0} g`}
                      />
                    </ListItem>
                  ))}
                </List>

                {combAlimentos.length > 0 &&
                  (() => {
                    const t = combAlimentos.reduce(
                      (acc, it) => {
                        const det =
                          it.ingrediente || ingById.get(it.ingredienteId);
                        return add(acc, scale(det, it.gramos || 0));
                      },
                      { ...ZERO }
                    );
                    return (
                      <Typography
                        variant="body2"
                        sx={{ mt: 1, color: "text.secondary" }}
                      >
                        Totales combinación · kcal {fmt(t.kcal, 0)} · P{" "}
                        {fmt(t.proteinas, 1)} · C {fmt(t.carbohidratos, 1)} · G{" "}
                        {fmt(t.grasas, 1)}
                      </Typography>
                    );
                  })()}

                <Box mt={2} mb={1}>
                  <TextField
                    label="Nombre de la combinación (Opcional)"
                    size="small"
                    fullWidth
                    value={combCustomName}
                    onChange={(e) => setCombCustomName(e.target.value)}
                    placeholder="Ej. Pollo con patatas"
                  />
                </Box>
                <Button
                  sx={{ mt: 1.5 }}
                  variant="contained"
                  onClick={addCombinationToMeal}
                  disabled={combAlimentos.length === 0 || !hasMeals}
                >
                  Añadir combinación a {comidas[activeComida]?.nombre || "—"}
                </Button>
              </Box>
            )}
          </Paper>

          {/* Opciones añadidas en la comida activa */}
          <Paper variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
            <Typography variant="h6" fontWeight={700}>
              {comidas[activeComida]?.nombre || "—"} · opciones
            </Typography>
            <Typography variant="body2" sx={{ mb: 1, color: "text.secondary" }}>
              Media aprox. · {fmt(mediasPorComida[activeComida]?.kcal, 0)} kcal
              · P {fmt(mediasPorComida[activeComida]?.proteinas, 1)} · C{" "}
              {fmt(mediasPorComida[activeComida]?.carbohidratos, 1)} · G{" "}
              {fmt(mediasPorComida[activeComida]?.grasas, 1)}
            </Typography>
            <Divider sx={{ mb: 1.5 }} />
            <Stack spacing={1}>
              {(comidas[activeComida]?.opciones || []).map((op, i) => {
                let preview = totalsForOption(op);

                const nombre =
                  op.tipo === "Receta"
                    ? op.receta?.nombre
                    : op.tipo === "Alimento"
                    ? `${op.ingrediente?.nombre} (${op.gramos} g)`
                    : op.nombre ||
                      (op.alimentos || [])
                        .map(
                          (it) =>
                            it?.ingrediente?.nombre ||
                            ingById.get(it.ingredienteId)?.nombre
                        )
                        .filter(Boolean)
                        .join(" + ");

                const icon =
                  op.tipo === "Receta" ? (
                    <RestaurantMenuIcon fontSize="small" />
                  ) : op.tipo === "Alimento" ? (
                    <LocalDiningIcon fontSize="small" />
                  ) : (
                    <EmojiFoodBeverageIcon fontSize="small" />
                  );

                return (
                  <Stack
                    key={i}
                    direction="row"
                    alignItems="center"
                    spacing={1}
                    sx={{
                      p: 1,
                      border: "1px dashed",
                      borderColor: "divider",
                      borderRadius: 1.5,
                    }}
                  >
                    {icon}
                    <Typography sx={{ flex: 1 }}>{nombre}</Typography>
                    <Typography variant="body2" color="text.secondary">
                      {fmt(preview.kcal, 0)} kcal · P{" "}
                      {fmt(preview.proteinas, 1)} · C{" "}
                      {fmt(preview.carbohidratos, 1)} · G{" "}
                      {fmt(preview.grasas, 1)}
                    </Typography>
                    <Tooltip title="Quitar">
                      <IconButton size="small" onClick={() => removeOpcion(i)}>
                        <DeleteOutlineIcon />
                      </IconButton>
                    </Tooltip>
                  </Stack>
                );
              })}
              {(comidas[activeComida]?.opciones || []).length === 0 && (
                <Typography variant="body2" color="text.secondary">
                  Aún no hay opciones en esta comida.
                </Typography>
              )}
            </Stack>
          </Paper>
        </Grid>

        {/* Panel lateral: totales */}
        <Grid item xs={12} md={5} lg={4}>
          <Paper variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
            <Typography variant="h6" fontWeight={700}>
              Totales (aprox.)
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
              Media por comida (promedio entre opciones)
            </Typography>
            <Divider sx={{ my: 1.5 }} />
            <Stack spacing={1}>
              {comidas.map((c, i) => (
                <Stack key={i} direction="row" justifyContent="space-between">
                  <Typography>{c.nombre}</Typography>
                  <Typography variant="body2" color="text.secondary">
                    {fmt(mediasPorComida[i]?.kcal, 0)} kcal · P{" "}
                    {fmt(mediasPorComida[i]?.proteinas, 1)} · C{" "}
                    {fmt(mediasPorComida[i]?.carbohidratos, 1)} · G{" "}
                    {fmt(mediasPorComida[i]?.grasas, 1)}
                  </Typography>
                </Stack>
              ))}
            </Stack>

            <Divider sx={{ my: 1.5 }} />
            <Typography variant="subtitle1" fontWeight={800}>
              Total dieta estimado: {fmt(totalEstimado.kcal, 0)} kcal
            </Typography>
            <Typography variant="body2" color="text.secondary">
              P {fmt(totalEstimado.proteinas, 1)} · C{" "}
              {fmt(totalEstimado.carbohidratos, 1)} · G{" "}
              {fmt(totalEstimado.grasas, 1)}
            </Typography>

            <Divider sx={{ my: 1.5 }} />
            <Typography variant="overline" color="text.secondary">
              Si comieras todas las opciones
            </Typography>
            <Typography variant="body2" color="text.secondary">
              {fmt(totalesGlobal.kcal, 0)} kcal · P{" "}
              {fmt(totalesGlobal.proteinas, 1)} · C{" "}
              {fmt(totalesGlobal.carbohidratos, 1)} · G{" "}
              {fmt(totalesGlobal.grasas, 1)}
            </Typography>
          </Paper>
        </Grid>
      </Grid>
      
      <Snackbar
        open={openError}
        autoHideDuration={4000}
        onClose={() => setOpenError(false)}
        anchorOrigin={{ vertical: "bottom", horizontal: "center" }}
      >
        <Alert onClose={() => setOpenError(false)} severity="error" sx={{ width: "100%" }}>
          {errorMsg}
        </Alert>
      </Snackbar>
    </Box>
  );
};

export default CrearDieta;
