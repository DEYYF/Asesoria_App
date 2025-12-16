// src/pages/EditarDieta.jsx
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
  Collapse,
  InputAdornment,
  Slider,
  Avatar,
  Snackbar,
  Alert,
} from "@mui/material";
import { useParams, useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { extractAsesorId } from "../utils/auth";
import { updateDieta } from "../services/dietas";

import AddIcon from "@mui/icons-material/Add";
import DeleteOutlineIcon from "@mui/icons-material/DeleteOutline";
import RestaurantMenuIcon from "@mui/icons-material/RestaurantMenu";
import LocalDiningIcon from "@mui/icons-material/LocalDining";
import EmojiFoodBeverageIcon from "@mui/icons-material/EmojiFoodBeverage";
import PlaylistAddIcon from "@mui/icons-material/PlaylistAdd";
import CloseIcon from "@mui/icons-material/Close";

import API from "../services/api";

// ---------- Helpers ----------
const ZERO = { kcal: 0, proteinas: 0, carbohidratos: 0, grasas: 0 };
const getId = (o) => {
  if (!o) return null;
  if (typeof o === "string") return o;
  return o._id || o.id || null;
};
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

// ---------- Página ----------
const EditarDieta = () => {
  const { id } = useParams(); // id de la dieta a editar
  const { user, token } = useAuth();
  const asesorId = useMemo(() => extractAsesorId(user, token), [user, token]);
  const navigate = useNavigate();

  // Documento original
  const [dietaDoc, setDietaDoc] = useState(null);

  // Objetivos
  const [objetivoInput, setObjetivoInput] = useState("");
  const [objetivos, setObjetivos] = useState([]);

  // Comidas y editor
  const [comidas, setComidas] = useState([]); // mismas estructuras que CrearDieta
  const [activeComida, setActiveComida] = useState(0);
  const [tab, setTab] = useState(0); // 0 Receta, 1 Alimento, 2 Combinación

  // Data catálogos
  const [recetasAll, setRecetasAll] = useState([]);
  const [ingredientesAll, setIngredientesAll] = useState([]);
  const [qReceta, setQReceta] = useState("");
  const [qIng, setQIng] = useState("");

  // Selecciones (alta de opciones nuevas)
  const [recetaSel, setRecetaSel] = useState(null);
  const [aliSel, setAliSel] = useState(null);
  const [aliGr, setAliGr] = useState("");
  const [combAlimentos, setCombAlimentos] = useState([]);
  const [combIngSel, setCombIngSel] = useState(null);
  const [combGr, setCombGr] = useState("");

  // Editor inline para añadir ingrediente a una combinación existente
  const [pendingCombItem, setPendingCombItem] = useState({
    open: false,
    mealIdx: null,
    optIdx: null,
    ingrediente: null,
    gramos: 100,
  });
  const openPendingItem = (mealIdx, optIdx, ingrediente) => {
    if (!ingrediente) return;
    setPendingCombItem({
      open: true,
      mealIdx,
      optIdx,
      ingrediente,
      gramos: 100,
    });
  };
  const cancelPendingItem = () =>
    setPendingCombItem((p) => ({ ...p, open: false }));
  const confirmPendingItem = () => {
    const g = Number(pendingCombItem.gramos);
    if (!Number.isFinite(g) || g <= 0) return;
    addItemToCombination(
      pendingCombItem.mealIdx,
      pendingCombItem.optIdx,
      pendingCombItem.ingrediente,
      g
    );
    cancelPendingItem();
  };

  // ---------- Carga de datos ----------
  useEffect(() => {
    const loadAll = async () => {
      try {
        const [dietRes, recRes, ingRes] = await Promise.all([
          API.get(`/dietas/${id}`),
          API.get("/comidas/recetas"),
          API.get("/comidas/ingredientes"),
        ]);
        const d = dietRes.data;
        setDietaDoc(d);
        setObjetivos(d?.objetivos || []);
        setRecetasAll(recRes.data || []);
        setIngredientesAll(ingRes.data || []);

        // Mapea dieta -> estado editable
        const ingMap = new Map(
          (ingRes.data || []).map((i) => [String(getId(i)), i])
        );
        const mapComidas = (d?.comidas || []).map((c) => {
          const opciones = (c.opciones || [])
            .map((op) => {
              // Backend uses lowercase types: receta, ingrediente, combinacion
              const tipo = (op.tipo || "").toLowerCase();

              if (tipo === "receta") {
                const rId = getId(op.recetaId) || getId(op.refId); // resolves string or object
                const recetaObj = recRes.data.find(
                  (r) => String(getId(r)) === String(rId)
                ) || { _id: rId, nombre: op.nombre || "Receta" };
                return { tipo: "Receta", receta: recetaObj };
              }
              if (tipo === "ingrediente" || tipo === "alimento") {
                const iId = op.ingredienteId || op.refId;
                const ingObj = ingMap.get(String(iId)) || {
                  _id: iId,
                  nombre: op.nombre || "Ingrediente",
                };
                return {
                  tipo: "Alimento",
                  ingrediente: ingObj,
                  gramos: op.gramos || 0,
                };
              }
              if (tipo === "combinacion") {
                const items = (op.items || []).map((it) => {
                  const itId = it.ingredienteId || it.ingrediente;
                  const ingObj = ingMap.get(String(itId)) || {
                    _id: itId,
                    nombre: it.nombre || "-",
                  };
                  return {
                    ingredienteId: String(itId),
                    ingrediente: ingObj,
                    gramos: it.gramos || 0,
                  };
                });
                const nombre = op.nombre ||
                  items
                    .map((x) => x.ingrediente?.nombre)
                    .filter(Boolean)
                    .join(" + ") || "Combinación";
                return { tipo: "Combinacion", nombre, alimentos: items };
              }
              return null;
            })
            .filter(Boolean);

          return { nombre: c.titulo || c.nombre || "Comida", opciones };
        });

        setComidas(
          mapComidas.length ? mapComidas : [{ nombre: "Comida", opciones: [] }]
        );
      } catch (e) {
        console.error("Error cargando edición de dieta:", e);
      }
    };
    loadAll();
  }, [id]);

  // Catálogo filtrado
  const recetas = useMemo(() => {
    const q = qReceta.trim().toLowerCase();
    if (!q) return recetasAll;
    return recetasAll.filter((r) =>
      (r?.nombre || "").toLowerCase().includes(q)
    );
  }, [recetasAll, qReceta]);

  const ingredientes = useMemo(() => {
    const q = qIng.trim().toLowerCase();
    if (!q) return ingredientesAll;
    return ingredientesAll.filter((i) =>
      (i?.nombre || "").toLowerCase().includes(q)
    );
  }, [ingredientesAll, qIng]);

  const ingById = useMemo(
    () => new Map(ingredientesAll.map((i) => [String(getId(i)), i])),
    [ingredientesAll]
  );

  // Validaciones
  const [errorMsg, setErrorMsg] = useState("");
  const [openError, setOpenError] = useState(false);
  const notifyError = (msg) => {
    setErrorMsg(msg);
    setOpenError(true);
  };

  // ---------- Cálculos ----------
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

  const totalesPorComida = useMemo(() => {
    return comidas.map((c) =>
      (c.opciones || [])
        .map(totalsForOption)
        .reduce((acc, cur) => add(acc, cur), { ...ZERO })
    );
  }, [comidas, ingById]);

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

  const totalesGlobal = useMemo(
    () => totalesPorComida.reduce((acc, t) => add(acc, t), { ...ZERO }),
    [totalesPorComida]
  );
  const totalEstimado = useMemo(
    () => mediasPorComida.reduce((acc, t) => add(acc, t), { ...ZERO }),
    [mediasPorComida]
  );

  // ---------- Mutadores ----------
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

  // Añadir NUEVA Receta
  const handleAddReceta = () => {
    if (!recetaSel) {
        notifyError("Por favor, selecciona una receta.");
        return;
    }
    pushOpcion({ tipo: "Receta", receta: recetaSel });
    setRecetaSel(null);
    setQReceta("");
  };

  // Añadir NUEVO Alimento
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

  // Añadir NUEVA combinación (builder)
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
        ingredienteId: String(getId(combIngSel)),
        gramos,
        ingrediente: combIngSel, // cache
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

  // Operaciones sobre opciones ya existentes
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

  // Alimento: actualizar gramos
  const updateAlimentoGr = (optIdx, grams) => {
    setComidas((prev) => {
      const next = [...prev];
      next[activeComida] = { ...next[activeComida] };
      const ops = [...(next[activeComida].opciones || [])];
      const op = { ...ops[optIdx], gramos: grams };
      ops[optIdx] = op;
      next[activeComida].opciones = ops;
      return next;
    });
  };

  // Combinación: quitar item
  const removeItemFromCombination = (optIdx, itemIdx) => {
    setComidas((prev) => {
      const next = [...prev];
      const combo = { ...next[activeComida].opciones[optIdx] };
      combo.alimentos = combo.alimentos.filter((_, i) => i !== itemIdx);
      // rename
      combo.nombre = combo.alimentos
        .map(
          (it) =>
            it?.ingrediente?.nombre || ingById.get(it.ingredienteId)?.nombre
        )
        .filter(Boolean)
        .join(" + ");
      next[activeComida].opciones[optIdx] = combo;
      return next;
    });
  };

  // Combinación: actualizar gramos de un item
  const updateItemGrams = (optIdx, itemIdx, grams) => {
    setComidas((prev) => {
      const next = [...prev];
      const combo = { ...next[activeComida].opciones[optIdx] };
      const items = [...combo.alimentos];
      items[itemIdx] = { ...items[itemIdx], gramos: grams };
      combo.alimentos = items;
      next[activeComida].opciones[optIdx] = combo;
      return next;
    });
  };

  // Combinación: añadir ingrediente (desde inline editor)
  const addItemToCombination = (mealIdx, optIdx, ingrediente, gramos) => {
    setComidas((prev) => {
      const next = [...prev];
      const combo = { ...next[mealIdx].opciones[optIdx] };
      const item = {
        ingredienteId: String(getId(ingrediente)),
        ingrediente,
        gramos: Number(gramos),
      };
      combo.alimentos = [...(combo.alimentos || []), item];
      combo.nombre = (combo.alimentos || [])
        .map(
          (it) =>
            it?.ingrediente?.nombre || ingById.get(it.ingredienteId)?.nombre
        )
        .filter(Boolean)
        .join(" + ");
      next[mealIdx].opciones[optIdx] = combo;
      return next;
    });
  };

  // Renombrar comida
  const setNombreComida = (i, nombre) => {
    setComidas((prev) => {
      const next = [...prev];
      next[i] = { ...next[i], nombre };
      return next;
    });
  };

  // Guardar (PUT)
  const handleGuardar = async () => {
    if (!dietaDoc?._id) return;

    // Validation
    for (let i = 0; i < comidas.length; i++) {
        const c = comidas[i];
        if (!c.nombre || !c.nombre.trim()) {
            notifyError(`La comida ${i + 1} debe tener un nombre.`);
            return;
        }
    }

    const payload = {
      clienteId: String(dietaDoc?.clienteId ?? dietaDoc?.cliente?._id ?? ""),
      asesorId: dietaDoc?.asesorId || undefined,
      nombre: dietaDoc?.nombre || "Dieta",
      objetivo: dietaDoc?.objetivo || "salud",
      estado: dietaDoc?.estado || "borrador",
      macros: {
        kcal: Number(totalEstimado?.kcal) || 0,
        p: Number(totalEstimado?.proteinas) || 0,
        c: Number(totalEstimado?.carbohidratos) || 0,
        g: Number(totalEstimado?.grasas) || 0,
      },
      notas: dietaDoc?.notas || "",
      comidas: (comidas || []).map((c) => ({
        titulo: c?.nombre || c?.titulo || "Comida",
        hora: c?.hora || undefined,
        notas: c?.notas || "",
        opciones: (c?.opciones || []).map((op) => {
          const tipo = (op?.tipo || "").toLowerCase();

          if (tipo === "receta") {
            const rId = op.recetaId || getId(op.receta);
            return {
              tipo: "receta",
              recetaId: rId ? String(rId) : undefined,
            };
          }

          if (tipo === "alimento" || tipo === "ingrediente") {
            const iId = op.ingredienteId || getId(op.ingrediente);
            return {
              tipo: "ingrediente",
              ingredienteId: iId ? String(iId) : undefined,
              nombre: op?.nombre || undefined,
              gramos: Number(op?.gramos) || 0,
              unidades:
                typeof op?.unidades === "number" ? op.unidades : undefined,
            };
          }

          // combinacion
          const arr = op?.alimentos || op?.items || [];
          return {
            tipo: "combinacion",
            nombre: op.nombre || undefined, // PERSIST CUSTOM NAME
            items: arr.map((it) => {
              const itId = it.ingredienteId || getId(it.ingrediente);
              return {
                ingredienteId: itId ? String(itId) : undefined,
                nombre: it?.nombre || undefined,
                gramos: Number(it?.gramos) || 0,
              };
            }),
            notas: op?.notas || "",
          };
        }),
      })),
    };

    try {
      const dietaNueva = await updateDieta(id, payload);
      
      if (!dietaNueva || !dietaNueva._id) {
          throw new Error("Respuesta inválida del servidor (sin ID)");
      }

      navigate(`/dieta/${dietaNueva._id}`);
    } catch (e) {
      console.error("Error actualizando dieta:", e);
      alert("No se pudo guardar la dieta.");
    }
  };

  if (!dietaDoc)
    return <Typography sx={{ p: 4 }}>Cargando edición...</Typography>;

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
          Editar dieta
        </Typography>
        <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
          <Button variant="outlined" onClick={() => navigate(-1)}>
            Volver
          </Button>
          <Button variant="contained" onClick={handleGuardar}>
            Guardar cambios
          </Button>
        </Stack>
      </Stack>

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
          {objetivos.map((o, i) => (
            <Chip
              key={i}
              label={o}
              onDelete={() =>
                setObjetivos((p) => p.filter((_, idx) => idx !== i))
              }
              sx={{ borderRadius: 2 }}
            />
          ))}
        </Stack>
      </Paper>

      <Grid container spacing={2}>
        {/* Creador / Menú (alta de nuevas opciones) */}
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
                value={{
                  label: comidas[activeComida]?.nombre,
                  value: activeComida,
                }}
                onChange={(_, v) => setActiveComida(v?.value ?? 0)}
                renderInput={(params) => (
                  <TextField
                    {...params}
                    label="Selecciona comida"
                    size="small"
                  />
                )}
              />
              <TextField
                size="small"
                label="Renombrar comida"
                value={comidas[activeComida]?.nombre || ""}
                onChange={(e) => setNombreComida(activeComida, e.target.value)}
              />
              <Button
                startIcon={<PlaylistAddIcon />}
                onClick={() =>
                  setComidas((p) => [
                    ...p,
                    { nombre: `Comida ${p.length + 1}`, opciones: [] },
                  ])
                }
              >
                Añadir comida
              </Button>
            </Stack>

            <Tabs value={tab} onChange={(_, v) => setTab(v)} sx={{ mt: 2 }}>
              <Tab
                icon={<RestaurantMenuIcon sx={{ mr: 1 }} />}
                iconPosition="start"
                label="Añadir Receta"
              />
              <Tab
                icon={<LocalDiningIcon sx={{ mr: 1 }} />}
                iconPosition="start"
                label="Añadir Alimento"
              />
              <Tab
                icon={<EmojiFoodBeverageIcon sx={{ mr: 1 }} />}
                iconPosition="start"
                label="Nueva Combinación"
              />
            </Tabs>

            {/* Alta Receta */}
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
                />
                {recetaSel && (
                  <Typography
                    variant="body2"
                    sx={{ mt: 1, color: "text.secondary" }}
                  >
                    kcal: <b>{fmt(recetaSel.caloriasTotales, 0)}</b> · P:{" "}
                    <b>{fmt(recetaSel.macrosTotales?.proteinas, 1)}</b> · C:{" "}
                    <b>{fmt(recetaSel.macrosTotales?.carbohidratos, 1)}</b> · G:{" "}
                    <b>{fmt(recetaSel.macrosTotales?.grasas, 1)}</b>
                  </Typography>
                )}
                <Button
                  sx={{ mt: 1.5 }}
                  variant="contained"
                  onClick={handleAddReceta}
                  disabled={!recetaSel}
                >
                  Añadir receta a {comidas[activeComida]?.nombre || "—"}
                </Button>
              </Box>
            )}

            {/* Alta Alimento */}
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
                  />
                  <TextField
                    label="Gramos"
                    size="small"
                    type="number"
                    value={aliGr}
                    onChange={(e) => setAliGr(e.target.value)}
                    sx={{ width: 140 }}
                    inputProps={{ min: 0 }}
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
                  disabled={!aliSel || !aliGr}
                >
                  Añadir alimento a {comidas[activeComida]?.nombre || "—"}
                </Button>
              </Box>
            )}

            {/* Builder Combinación */}
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
                      <TextField {...params} label="Ingrediente" size="small" />
                    )}
                  />
                  <TextField
                    label="Gramos"
                    size="small"
                    type="number"
                    value={combGr}
                    onChange={(e) => setCombGr(e.target.value)}
                    sx={{ width: 140 }}
                    inputProps={{ min: 0 }}
                  />
                  <Button
                    variant="outlined"
                    onClick={addCombItem}
                    startIcon={<AddIcon />}
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
                  disabled={combAlimentos.length === 0}
                >
                  Añadir combinación a {comidas[activeComida]?.nombre || "—"}
                </Button>
              </Box>
            )}
          </Paper>

          {/* Opciones existentes de la comida activa */}
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

            <Stack spacing={1.25}>
              {(comidas[activeComida]?.opciones || []).map((op, i) => {
                const preview = totalsForOption(op);

                // Etiqueta
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
                  <Box
                    key={i}
                    sx={{
                      p: 1.25,
                      border: "1px dashed",
                      borderColor: "divider",
                      borderRadius: 1.5,
                    }}
                  >
                    <Stack direction="row" spacing={1} alignItems="center">
                      {icon}
                      <Typography sx={{ flex: 1 }}>{nombre}</Typography>
                      <Typography variant="body2" color="text.secondary">
                        {fmt(preview.kcal, 0)} kcal · P{" "}
                        {fmt(preview.proteinas, 1)} · C{" "}
                        {fmt(preview.carbohidratos, 1)} · G{" "}
                        {fmt(preview.grasas, 1)}
                      </Typography>
                      <Tooltip title="Eliminar opción">
                        <IconButton
                          size="small"
                          onClick={() => removeOpcion(i)}
                        >
                          <DeleteOutlineIcon />
                        </IconButton>
                      </Tooltip>
                    </Stack>

                    {/* Si es receta: listar ingredientes + link */}
                    {op.tipo === "Receta" && op.receta && (
                      <Box sx={{ mt: 1 }}>
                        <Box
                          display="flex"
                          justifyContent="space-between"
                          alignItems="center"
                        >
                          <Typography
                            variant="caption"
                            sx={{ fontWeight: 600, color: "text.secondary" }}
                          >
                            Ingredientes
                          </Typography>
                          {op.receta.linkPreparacion && (
                            <a
                              href={op.receta.linkPreparacion}
                              target="_blank"
                              rel="noopener noreferrer"
                              style={{ textDecoration: "none" }}
                            >
                              <Typography
                                variant="caption"
                                sx={{
                                  fontSize: "0.7rem",
                                  color: "primary.main",
                                  fontWeight: 700,
                                }}
                              >
                                VER PREPARACION ↗
                              </Typography>
                            </a>
                          )}
                        </Box>
                        <Stack spacing={0.5} mt={0.5} pl={1}>
                          {(op.receta.ingredientes || []).map((ing, idx) => (
                            <Typography
                              key={idx}
                              variant="body2"
                              color="text.secondary"
                              sx={{ fontSize: "0.85rem" }}
                            >
                              • {ing.nombre || "Ingrediente"} ({ing.gramos || 0}{" "}
                              g)
                            </Typography>
                          ))}
                        </Stack>
                      </Box>
                    )}

                    {/* Si es alimento: permitir editar gramos */}
                    {op.tipo === "Alimento" && (
                      <Stack
                        direction="row"
                        spacing={1.25}
                        alignItems="center"
                        sx={{ mt: 1 }}
                      >
                        <TextField
                          label="Gramos"
                          size="small"
                          type="number"
                          value={op.gramos}
                          onChange={(e) =>
                            updateAlimentoGr(i, Number(e.target.value))
                          }
                          sx={{ width: 140 }}
                          inputProps={{ min: 1 }}
                          InputProps={{
                            endAdornment: (
                              <InputAdornment position="end">g</InputAdornment>
                            ),
                          }}
                        />
                        <Slider
                          value={Number(op.gramos) || 0}
                          min={10}
                          max={1000}
                          step={5}
                          valueLabelDisplay="auto"
                          onChange={(_, v) => updateAlimentoGr(i, v)}
                          sx={{ flex: 1, minWidth: 180 }}
                        />
                      </Stack>
                    )}

                    {/* Si es combinación: listar items + edición de gramos + añadir nuevo inline */}
                    {op.tipo === "Combinacion" && (
                      <Box sx={{ mt: 1 }}>
                        <Stack spacing={1}>
                          {(op.alimentos || []).map((it, idx) => {
                            const itPrev = scale(
                              it.ingrediente || ingById.get(it.ingredienteId),
                              it.gramos || 0
                            );
                            return (
                              <Stack
                                key={idx}
                                direction={{ xs: "column", md: "row" }}
                                spacing={1.25}
                                alignItems={{ md: "center" }}
                                sx={{
                                  p: 1,
                                  borderRadius: 1,
                                  border: "1px solid",
                                  borderColor: "divider",
                                }}
                              >
                                <Typography sx={{ flex: 1 }}>
                                  {it?.ingrediente?.nombre ||
                                    ingById.get(it.ingredienteId)?.nombre ||
                                    "-"}
                                </Typography>

                                <TextField
                                  size="small"
                                  label="Gramos"
                                  type="number"
                                  value={it.gramos}
                                  onChange={(e) =>
                                    updateItemGrams(
                                      i,
                                      idx,
                                      Number(e.target.value)
                                    )
                                  }
                                  sx={{ width: 130 }}
                                  inputProps={{ min: 1 }}
                                  InputProps={{
                                    endAdornment: (
                                      <InputAdornment position="end">
                                        g
                                      </InputAdornment>
                                    ),
                                  }}
                                />
                                <Slider
                                  value={Number(it.gramos) || 0}
                                  min={10}
                                  max={1000}
                                  step={5}
                                  valueLabelDisplay="auto"
                                  onChange={(_, v) =>
                                    updateItemGrams(i, idx, v)
                                  }
                                  sx={{ flex: 1, minWidth: 160 }}
                                />

                                <Typography
                                  variant="body2"
                                  color="text.secondary"
                                  sx={{ minWidth: 200 }}
                                >
                                  ≈ {fmt(itPrev.kcal, 0)} kcal · P{" "}
                                  {fmt(itPrev.proteinas, 1)} · C{" "}
                                  {fmt(itPrev.carbohidratos, 1)} · G{" "}
                                  {fmt(itPrev.grasas, 1)}
                                </Typography>

                                <Tooltip title="Quitar ingrediente">
                                  <IconButton
                                    onClick={() =>
                                      removeItemFromCombination(i, idx)
                                    }
                                  >
                                    <DeleteOutlineIcon />
                                  </IconButton>
                                </Tooltip>
                              </Stack>
                            );
                          })}
                        </Stack>

                        {/* Añadir ingrediente a esta combinación */}
                        <Stack
                          direction={{ xs: "column", sm: "row" }}
                          spacing={1}
                          alignItems={{ sm: "center" }}
                          sx={{ mt: 1 }}
                        >
                          <Autocomplete
                            sx={{ flex: 1 }}
                            options={ingredientes}
                            getOptionLabel={(o) => o?.nombre || ""}
                            onInputChange={(_, v) => setQIng(v)}
                            value={null}
                            onChange={(_, v) => {
                              if (v) openPendingItem(activeComida, i, v);
                            }}
                            renderInput={(params) => (
                              <TextField
                                {...params}
                                label="Añadir ingrediente a esta combinación"
                                size="small"
                              />
                            )}
                          />
                        </Stack>

                        {/* Editor inline de gramos (bonito) */}
                        <Collapse
                          in={
                            pendingCombItem.open &&
                            pendingCombItem.mealIdx === activeComida &&
                            pendingCombItem.optIdx === i
                          }
                          unmountOnExit
                        >
                          <Stack
                            direction={{ xs: "column", md: "row" }}
                            spacing={1.5}
                            alignItems={{ md: "center" }}
                            sx={{
                              mt: 1,
                              p: 1.5,
                              borderRadius: 1.5,
                              border: "1px dashed",
                              borderColor: "divider",
                              bgcolor: "background.default",
                            }}
                          >
                            <Stack
                              direction="row"
                              spacing={1.25}
                              alignItems="center"
                              sx={{ minWidth: 220 }}
                            >
                              <Avatar
                                sx={{
                                  bgcolor: "primary.light",
                                  color: "primary.dark",
                                  width: 30,
                                  height: 30,
                                }}
                              >
                                {(pendingCombItem.ingrediente?.nombre || "I")
                                  .slice(0, 1)
                                  .toUpperCase()}
                              </Avatar>
                              <Typography
                                variant="subtitle2"
                                fontWeight={700}
                                noWrap
                              >
                                {pendingCombItem.ingrediente?.nombre || "-"}
                              </Typography>
                              <IconButton
                                size="small"
                                onClick={cancelPendingItem}
                                sx={{ ml: "auto" }}
                              >
                                <CloseIcon fontSize="small" />
                              </IconButton>
                            </Stack>

                            <TextField
                              size="small"
                              label="Gramos"
                              type="number"
                              value={pendingCombItem.gramos}
                              onChange={(e) =>
                                setPendingCombItem((p) => ({
                                  ...p,
                                  gramos: e.target.value,
                                }))
                              }
                              onKeyDown={(e) => {
                                if (e.key === "Enter") confirmPendingItem();
                                if (e.key === "Escape") cancelPendingItem();
                              }}
                              inputProps={{ min: 1, step: 1 }}
                              InputProps={{
                                endAdornment: (
                                  <InputAdornment position="end">
                                    g
                                  </InputAdornment>
                                ),
                              }}
                              sx={{ width: 140 }}
                            />

                            <Slider
                              value={Number(pendingCombItem.gramos) || 0}
                              min={10}
                              max={1000}
                              step={5}
                              valueLabelDisplay="auto"
                              onChange={(_, v) =>
                                setPendingCombItem((p) => ({ ...p, gramos: v }))
                              }
                              sx={{ flex: 1, minWidth: 180 }}
                            />

                            {!!Number(pendingCombItem.gramos) &&
                              pendingCombItem.ingrediente && (
                                <Typography
                                  variant="body2"
                                  color="text.secondary"
                                  sx={{ minWidth: 220 }}
                                >
                                  {(() => {
                                    const t = scale(
                                      pendingCombItem.ingrediente,
                                      Number(pendingCombItem.gramos) || 0
                                    );
                                    return `≈ ${fmt(t.kcal, 0)} kcal · P ${fmt(
                                      t.proteinas,
                                      1
                                    )} · C ${fmt(t.carbohidratos, 1)} · G ${fmt(
                                      t.grasas,
                                      1
                                    )}`;
                                  })()}
                                </Typography>
                              )}

                            <Stack
                              direction="row"
                              spacing={1}
                              sx={{ minWidth: 180 }}
                            >
                              <Button onClick={cancelPendingItem}>
                                Cancelar
                              </Button>
                              <Button
                                variant="contained"
                                onClick={confirmPendingItem}
                                disabled={
                                  !Number(pendingCombItem.gramos) ||
                                  Number(pendingCombItem.gramos) <= 0
                                }
                              >
                                Añadir
                              </Button>
                            </Stack>
                          </Stack>
                        </Collapse>
                      </Box>
                    )}
                  </Box>
                );
              })}
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

export default EditarDieta;
