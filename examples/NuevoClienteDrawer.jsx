import React, { useEffect, useState, useMemo } from "react";
import {
  Drawer,
  Box,
  Typography,
  TextField,
  Button,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Divider,
  CircularProgress,
  Chip,
} from "@mui/material";

import API from "../services/api";
import { useAuth } from "../context/AuthContext";
import { extractAsesorId } from "../utils/auth";

const NuevoClienteDrawer = ({ open, onClose, onCreated }) => {
  const { user, token } = useAuth();
  const asesorId = useMemo(() => extractAsesorId(user, token), [user, token]);

  const [nombre, setNombre] = useState("");
  const [nombreError, setNombreError] = useState(false);
  const [email, setEmail] = useState("");
  const [emailError, setEmailError] = useState(false);
  const [telefono, setTelefono] = useState("");
  const [telefonoError, setTelefonoError] = useState(false);
  const [edad, setEdad] = useState("");
  const [sexo, setSexo] = useState("");
  const [objetivoInput, setObjetivoInput] = useState("");
  const [objetivos, setObjetivos] = useState([]);

  // TARIFAS + EXTRAS
  const [tarifasList, setTarifasList] = useState([]);
  const [extrasList, setExtrasList] = useState([]);

  const [selectedTarifaId, setSelectedTarifaId] = useState("");
  const [selectedExtras, setSelectedExtras] = useState([]);

  // CALCULOS
  const [tarifaData, setTarifaData] = useState(null);
  const [meses, setMeses] = useState(0);
  const [totalTarifa, setTotalTarifa] = useState(0);
  const [totalExtras, setTotalExtras] = useState(0);
  const [totalFinal, setTotalFinal] = useState(0);

  const [loading, setLoading] = useState(false);

  const objetivosSugeridos = [
    "Pérdida de peso",
    "Ganar masa muscular",
    "Mantenimiento",
    "Definición",
    "Aumentar fuerza",
    "Mejorar salud",
  ];

  const addObjetivo = () => {
    const val = objetivoInput.trim();
    if (!val) return;
    // Validate objective: only letters, numbers, spaces, and basic punctuation
    const validPattern = /^[a-zA-ZáéíóúÁÉÍÓÚñÑ0-9\s.,;:\-()]+$/;
    if (!validPattern.test(val)) {
      alert("El objetivo contiene caracteres no válidos");
      return;
    }
    if (!objetivos.includes(val)) setObjetivos((prev) => [...prev, val]);
    setObjetivoInput("");
  };

  const removeObjetivo = (val) => {
    setObjetivos((prev) => prev.filter((o) => o !== val));
  };

  // Cargar tarifas y extras reales
  useEffect(() => {
    const loadData = async () => {
      try {
        const t = await API.get("/tarifas");
        const e = await API.get("/extras");

        setTarifasList(t.data);
        setExtrasList(e.data);
      } catch (err) {
        console.error("Error cargando tarifas/extras", err);
      }
    };
    loadData();
  }, []);

  // Calcular totales cuando cambia tarifa o extras
  useEffect(() => {
    const tData = tarifasList.find((t) => t._id === selectedTarifaId);

    if (!tData) {
      setTarifaData(null);
      setMeses(0);
      setTotalTarifa(0);
      setTotalExtras(0);
      setTotalFinal(0);
      return;
    }

    setTarifaData(tData);

    const m = Math.ceil(tData.duracionDias / 30);
    setMeses(m);

    const base = tData.precio;
    setTotalTarifa(base);

    const extrasCost = selectedExtras.reduce((acc, id) => {
      const ext = extrasList.find((e) => e._id === id);
      return ext ? acc + ext.precio * m : acc;
    }, 0);

    setTotalExtras(extrasCost);
    setTotalFinal(base + extrasCost);
  }, [selectedTarifaId, selectedExtras, tarifasList]);

  // Función principal: crear cliente + presupuesto
  const crearCliente = async () => {
    try {
      if (!asesorId) {
        alert("No se ha podido identificar al asesor. Recarga la página.");
        return;
      }

      if (objetivos.length === 0) {
        alert("Debes añadir al menos un objetivo.");
        return;
      }

      // Validar email
      const emailRegex = /^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}$/;
      if (!emailRegex.test(email)) {
        setEmailError(true);
        return;
      }

      setLoading(true);

      if (!selectedTarifaId) {
        alert("Debes seleccionar una tarifa");
        setLoading(false);
        return;
      }

      // 1️⃣ Crear cliente
      const clienteRes = await API.post("/clientes", {
        nombre,
        email,
        telefono,
        edad: edad ? Number(edad) : null,
        sexo,
        objetivos, // Array requerido
        asesorId,
      });

      const clienteId = clienteRes.data._id;

      // 2️⃣ Calcular fechas (solo para visualización o si el backend lo usara)
      const fechaInicio = new Date();
      // El backend calcula fechaFin en base a la tarifa, pero enviamos fechaInicio.

      // 3️⃣ Crear presupuesto automático
      await API.post("/presupuestos", {
        clienteId,
        usuarioId: asesorId, // El asesor crea el presupuesto
        tarifaId: selectedTarifaId,
        extras: selectedExtras,
        fechaInicio,
      });

      setLoading(false);
      if (onCreated) onCreated();
      onClose();
    } catch (err) {
      console.error("Error creando cliente:", err);
      const msg = err.response?.data?.error || err.message || "Error creando cliente";
      alert(msg);
      setLoading(false);
    }
  };

  return (
    <Drawer anchor="right" open={open} onClose={onClose}>
      <Box sx={{ width: 400, p: 3 }}>
        <Typography variant="h5" fontWeight={700} sx={{ mb: 2 }}>
          Nuevo Cliente
        </Typography>

        {/* DATOS BÁSICOS */}
        <TextField
          fullWidth
          margin="normal"
          label="Nombre"
          value={nombre}
          error={nombreError}
          helperText={nombreError ? "Solo se permiten letras y espacios" : ""}
          onChange={(e) => {
            const value = e.target.value;
            // Only allow letters, spaces, and accented characters
            const validPattern = /^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]*$/;
            if (validPattern.test(value)) {
              setNombre(value);
              setNombreError(false);
            } else {
              setNombreError(true);
            }
          }}
        />
        <TextField
          fullWidth
          margin="normal"
          label="Email"
          type="email"
          value={email}
          error={emailError}
          helperText={emailError ? "Email inválido" : ""}
          onChange={(e) => {
            setEmail(e.target.value);
            if (emailError) setEmailError(false);
          }}
          onBlur={() => {
            const emailRegex = /^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}$/;
            if (email && !emailRegex.test(email)) {
              setEmailError(true);
            }
          }}
        />
        <TextField
          fullWidth
          margin="normal"
          label="Teléfono"
          value={telefono}
          error={telefonoError}
          helperText={telefonoError ? "Solo se permiten números, espacios, + y -" : ""}
          onChange={(e) => {
            const value = e.target.value;
            // Only allow numbers, spaces, +, and -
            const validPattern = /^[0-9\s+\-]*$/;
            if (validPattern.test(value)) {
              setTelefono(value);
              setTelefonoError(false);
            } else {
              setTelefonoError(true);
            }
          }}
        />

        <TextField
          fullWidth
          margin="normal"
          label="Edad"
          type="number"
          value={edad}
          onChange={(e) => setEdad(e.target.value)}
          inputProps={{ min: 0, max: 120, step: 1 }}
        />

        <FormControl fullWidth margin="normal">
          <InputLabel>Sexo</InputLabel>
          <Select value={sexo} label="Sexo" onChange={(e) => setSexo(e.target.value)}>
            <MenuItem value="Hombre">Hombre</MenuItem>
            <MenuItem value="Mujer">Mujer</MenuItem>
            <MenuItem value="Otro">Otro</MenuItem>
          </Select>
        </FormControl>

        <Typography variant="subtitle2" sx={{ mt: 2, mb: 1 }}>
          Objetivos *
        </Typography>
        <Box sx={{ display: "flex", gap: 1, mb: 1 }}>
          <TextField
            size="small"
            fullWidth
            placeholder="Escribe un objetivo..."
            value={objetivoInput}
            onChange={(e) => setObjetivoInput(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") {
                e.preventDefault();
                addObjetivo();
              }
            }}
          />
          <Button variant="outlined" onClick={addObjetivo}>
            Añadir
          </Button>
        </Box>

        <Box sx={{ display: "flex", flexWrap: "wrap", gap: 1, mb: 2 }}>
          {objetivos.map((o) => (
            <Chip key={o} label={o} onDelete={() => removeObjetivo(o)} color="primary" />
          ))}
        </Box>

        <Typography variant="caption" color="text.secondary">
          Sugerencias:
        </Typography>
        <Box sx={{ display: "flex", flexWrap: "wrap", gap: 0.5, mt: 0.5 }}>
          {objetivosSugeridos.map((sug) => (
            <Chip
              key={sug}
              label={sug}
              size="small"
              variant="outlined"
              onClick={() => {
                if (!objetivos.includes(sug)) setObjetivos((prev) => [...prev, sug]);
              }}
              sx={{ cursor: "pointer" }}
            />
          ))}
        </Box>

        <Divider sx={{ my: 3 }} />

        {/* TARIFA */}
        <FormControl fullWidth margin="normal">
          <InputLabel>Tarifa *</InputLabel>
          <Select
            value={selectedTarifaId}
            label="Tarifa *"
            onChange={(e) => setSelectedTarifaId(e.target.value)}
          >
            <MenuItem value="">
              <em>— Selecciona una tarifa —</em>
            </MenuItem>

            {tarifasList.map((t) => (
              <MenuItem key={t._id} value={t._id}>
                {t.nombre} — {t.precio}€ / {Math.ceil(t.duracionDias / 30)} mes(es)
              </MenuItem>
            ))}
          </Select>
        </FormControl>

        {/* EXTRAS */}
        <FormControl fullWidth margin="normal">
          <InputLabel>Extras mensuales</InputLabel>
          <Select
            multiple
            value={selectedExtras}
            label="Extras mensuales"
            onChange={(e) => setSelectedExtras(e.target.value)}
            renderValue={(sel) =>
              sel.map((id) => extrasList.find((e) => e._id === id)?.nombre).join(", ")
            }
          >
            {extrasList.map((ext) => (
              <MenuItem key={ext._id} value={ext._id}>
                {ext.nombre} — {ext.precio} €/mes
              </MenuItem>
            ))}
          </Select>
        </FormControl>

        {/* RESUMEN */}
        {selectedTarifaId && (
          <Box
            sx={{
              p: 2,
              border: "1px solid #ddd",
              borderRadius: 2,
              mt: 2,
              bgcolor: "#fafafa",
            }}
          >
            <Typography variant="subtitle1" fontWeight={700}>
              Resumen
            </Typography>

            <Typography>Tarifa base: {totalTarifa} €</Typography>
            <Typography>
              Extras: {totalExtras} € (duración: {meses} mes(es))
            </Typography>

            <Typography variant="h6" sx={{ mt: 1 }}>
              Total final: {totalFinal} €
            </Typography>
          </Box>
        )}

        {/* BOTÓN GUARDAR */}
        <Button
          variant="contained"
          fullWidth
          sx={{ mt: 3, py: 1.4, fontWeight: 700 }}
          onClick={crearCliente}
          disabled={loading}
        >
          {loading ? <CircularProgress size={24} /> : "Crear Cliente"}
        </Button>
      </Box>
    </Drawer>
  );
};

export default NuevoClienteDrawer;
