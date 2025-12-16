import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  TextField,
  MenuItem,
  FormControl,
  InputLabel,
  Select,
  FormHelperText,
} from "@mui/material";
import { useState } from "react";
import API from "../../services/api";

const DialogEditarInformacion = ({ open, onClose, cliente, onActualizar }) => {
  const [form, setForm] = useState({
    email: cliente.email || "",
    telefono: cliente.telefono || "",
    sexo: cliente.sexo || "",
    altura: cliente.altura || "",
  });

  const [errores, setErrores] = useState({});

  const validar = () => {
    const nuevosErrores = {};
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    if (!emailRegex.test(form.email)) {
      nuevosErrores.email = "Correo no válido";
    }

    if (!/^\d{7,15}$/.test(form.telefono)) {
      nuevosErrores.telefono = "Teléfono no válido (7 a 15 dígitos)";
    }

    if (!form.sexo) {
      nuevosErrores.sexo = "Debe seleccionar el sexo";
    }

    if (!form.altura || form.altura <= 0) {
      nuevosErrores.altura = "Altura no válida";
    }

    setErrores(nuevosErrores);
    return Object.keys(nuevosErrores).length === 0;
  };

  const handleChange = (e) => {
    const { name, value } = e.target;

    // Validación en tiempo real del teléfono (solo dígitos)
    if (name === "telefono") {
      if (!/^\d*$/.test(value)) return;
    }

    setForm({ ...form, [name]: value });
    setErrores({ ...errores, [name]: "" });
  };

  const handleGuardar = async () => {
    if (!validar()) return;

    try {
      await API.put(`/clientes/${cliente._id}`, {
        ...cliente,
        email: form.email,
        telefono: form.telefono,
        sexo: form.sexo,
        altura: form.altura,
      });
      onActualizar();
      onClose();
    } catch (err) {
      console.error("Error al actualizar cliente:", err);
    }
  };

  return (
    <Dialog open={open} onClose={onClose} fullWidth maxWidth="sm">
      <DialogTitle>Editar información del cliente</DialogTitle>
      <DialogContent>
        <TextField
          fullWidth
          label="Email"
          name="email"
          value={form.email}
          onChange={handleChange}
          margin="normal"
          error={!!errores.email}
          helperText={errores.email}
        />
        <TextField
          fullWidth
          label="Teléfono"
          name="telefono"
          value={form.telefono}
          onChange={handleChange}
          margin="normal"
          error={!!errores.telefono}
          helperText={errores.telefono}
          inputProps={{ maxLength: 15 }}
        />
        <FormControl fullWidth margin="normal" error={!!errores.sexo}>
          <InputLabel>Sexo</InputLabel>
          <Select
            name="sexo"
            value={form.sexo}
            onChange={handleChange}
            label="Sexo"
          >
            <MenuItem value="Hombre">Hombre</MenuItem>
            <MenuItem value="Mujer">Mujer</MenuItem>
            <MenuItem value="Otro">Otro</MenuItem>
          </Select>
          {errores.sexo && <FormHelperText>{errores.sexo}</FormHelperText>}
        </FormControl>
        <TextField
          fullWidth
          label="Altura (cm)"
          name="altura"
          type="number"
          value={form.altura}
          onChange={handleChange}
          margin="normal"
          error={!!errores.altura}
          helperText={errores.altura}
        />
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancelar</Button>
        <Button onClick={handleGuardar} variant="contained">
          Guardar
        </Button>
      </DialogActions>
    </Dialog>
  );
};

export default DialogEditarInformacion;