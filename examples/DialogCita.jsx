// src/components/DialogCita.jsx
import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Button,
  Stack,
  Snackbar,
  Alert,
  Box,
  Typography,
} from "@mui/material";
import { useEffect, useMemo, useState, useCallback, memo } from "react";
import API from "../services/api";
import { useAuth } from "../context/AuthContext";
import { extractAsesorId } from "../utils/auth";

const todayStr = () => new Date().toISOString().slice(0, 10); // 'YYYY-MM-DD'
const pad = (n) => String(n).padStart(2, "0");
const nowHHmm = () => {
  const d = new Date();
  return `${pad(d.getHours())}:${pad(d.getMinutes())}`;
};

// Normaliza el teléfono para WhatsApp (por defecto España +34)
function formatPhoneForWa(raw, defaultCc = "+34") {
  if (!raw) return null;
  let digits = String(raw).replace(/[^\d+]/g, "");
  if (digits.startsWith("00")) digits = "+" + digits.slice(2);
  if (!digits.startsWith("+")) {
    if (/^\d{9}$/.test(digits)) return (defaultCc + digits).replace(/\+/g, "");
    if (/^34\d{9}$/.test(digits)) return digits; // ya incluye 34
    return digits;
  }
  return digits.replace("+", ""); // E164 sin '+'
}

function fechaBonita(yyyy_mm_dd) {
  try {
    return new Date(`${yyyy_mm_dd}T00:00:00`).toLocaleDateString("es-ES");
  } catch {
    return yyyy_mm_dd || "-";
  }
}

function buildWhatsAppText({ accion, nombre, title, date, hora, horaFin, notas }) {
  const f = fechaBonita(date);
  const hIni = hora ? ` a las ${hora}` : "";
  const hFin = horaFin ? ` (hasta ${horaFin})` : "";
  const encabezado = accion === "crear" ? "Cita agendada" : accion === "editar" ? "Cita actualizada" : "Cita";
  let txt = `Hola ${nombre || ""},\n\n${encabezado} para el ${f}${hIni}${hFin}.\n`;
  txt += `Título: ${title}\n`;
  if (notas && notas.trim()) txt += `Notas: ${notas.trim()}\n`;
  txt += `\nSi necesitas reprogramar, avísame por aquí.`;
  return txt;
}

function openWhatsApp(phoneE164NoPlus, message) {
  if (!phoneE164NoPlus) return false;
  const url = `https://wa.me/${phoneE164NoPlus}?text=${encodeURIComponent(message)}`;
  const win = window.open(url, "_blank", "noopener,noreferrer");
  return !!win;
}

function DialogCita({
  abierto,
  onClose,
  cliente,      // { _id, nombre, telefono, email... }
  cita = null,  // objeto cita completo cuando editas
  modo = "crear",
}) {
  const { user, token } = useAuth();
  const asesorId = useMemo(() => extractAsesorId(user, token), [user, token]);

  const isEdit = modo === "editar" && cita?._id;

  const [title, setTitle]   = useState("");
  const [date, setDate]     = useState(todayStr());
  const [hora, setHora]     = useState(nowHHmm());
  const [horaFin, setHoraFin] = useState("");
  const [color, setColor]   = useState("#1976d2");
  const [notas, setNotas]   = useState("");
  const [sending, setSending] = useState(false);
  const [toast, setToast]   = useState({ open: false, sev: "success", msg: "" });

  useEffect(() => {
    if (!abierto) return;
    if (isEdit) {
      setTitle(cita?.title || "");
      setDate(cita?.date || todayStr());
      setHora(cita?.hora || "");
      setHoraFin(cita?.horaFin || "");
      setColor(cita?.color || "#1976d2");
      setNotas(cita?.notas || "");
    } else {
      setTitle(`Cita con ${cliente?.nombre || "cliente"}`);
      setDate(todayStr());
      setHora(nowHHmm());
      setHoraFin("");
      setColor("#1976d2");
      setNotas("");
    }
  }, [abierto, isEdit, cita?.title, cita?.date, cita?.hora, cita?.horaFin, cita?.color, cita?.notas, cliente?.nombre]);

  const canSave = useMemo(() => {
    return (
      asesorId &&
      (cliente?._id || cita?.clienteId) &&
      title.trim() &&
      date &&
      (!hora || /^\d{2}:\d{2}$/.test(hora)) &&
      (!horaFin || /^\d{2}:\d{2}$/.test(horaFin))
    );
  }, [asesorId, cliente?._id, cita?.clienteId, title, date, hora, horaFin]);

  const handleSave = useCallback(async () => {
    if (!canSave) {
      setToast({
        open: true,
        sev: "warning",
        msg: "Completa título y fecha. Hora opcional, pero en formato HH:mm.",
      });
      return;
    }
    setSending(true);
    try {
      let saved;
      if (isEdit) {
        const { data } = await API.put(`/citas/${cita._id}`, {
          title: title.trim(),
          date,
          hora: hora || null,
          horaFin: horaFin || null,
          clienteId: cita.clienteId || cliente?._id,
          color,
          notas,
        });
        saved = data;
      } else {
        const { data } = await API.post("/citas", {
          asesorId,
          title: title.trim(),
          date,
          hora,
          horaFin: horaFin || null,
          clienteId: cliente._id,
          color,
          notas,
        });
        saved = data;
      }

      const phone = formatPhoneForWa(cliente?.telefono);
      if (phone) {
        const text = buildWhatsAppText({
          accion: isEdit ? "editar" : "crear",
          nombre: cliente?.nombre,
          title,
          date,
          hora,
          horaFin,
          notas,
        });
        const opened = openWhatsApp(phone, text);
        setToast({
          open: true,
          sev: opened ? "success" : "warning",
          msg: opened
            ? `Cita ${isEdit ? "actualizada" : "creada"} y WhatsApp preparado.`
            : "Cita guardada. No pude abrir WhatsApp (bloqueo de pop-ups).",
        });
      } else {
        setToast({
          open: true,
          sev: "warning",
          msg: "Cita guardada, pero el cliente no tiene teléfono válido para WhatsApp.",
        });
      }

      onClose?.(saved);
    } catch (e) {
      console.error(isEdit ? "PUT /citas/:id" : "POST /citas", e);
      setToast({
        open: true,
        sev: "error",
        msg: `No se pudo ${isEdit ? "actualizar" : "crear"} la cita.`,
      });
    } finally {
      setSending(false);
    }
  }, [
    canSave,
    isEdit,
    cita?._id,
    cita?.clienteId,
    title,
    date,
    hora,
    horaFin,
    cliente?._id,
    cliente?.nombre,
    cliente?.telefono,
    color,
    notas,
    asesorId,
    onClose,
  ]);

  const closeDialog = useCallback(() => onClose?.(null), [onClose]);
  const closeToast = useCallback(
    () => setToast((p) => ({ ...p, open: false })),
    []
  );

  return (
    <>
      <Dialog
        open={!!abierto}
        onClose={sending ? undefined : closeDialog}
        fullWidth
        maxWidth="sm"
        PaperProps={{ sx: { borderRadius: 3, overflow: "hidden" } }}
      >
        <Box
          sx={{
            px: 3,
            pt: 2,
            pb: 1,
            borderBottom: "1px solid",
            borderColor: "divider",
            background:
              "linear-gradient(180deg, rgba(246,247,251,0.7) 0%, rgba(255,255,255,1) 45%)",
          }}
        >
          <DialogTitle sx={{ p: 0, fontWeight: 800 }}>
            {isEdit
              ? `Editar cita${cliente?.nombre ? ` de ${cliente.nombre}` : ""}`
              : `Añadir cita${cliente?.nombre ? ` con ${cliente.nombre}` : ""}`}
          </DialogTitle>
          <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
            Rellena los datos. Se abrirá WhatsApp con el mensaje listo para enviar.
          </Typography>
        </Box>

        <DialogContent sx={{ p: 3 }}>
          <Stack spacing={2}>
            <TextField
              label="Título"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              fullWidth
            />

            <Stack direction={{ xs: "column", sm: "row" }} spacing={2}>
              <TextField
                label="Fecha"
                type="date"
                value={date}
                onChange={(e) => setDate(e.target.value)}
                sx={{ flex: 1 }}
                InputLabelProps={{ shrink: true }}
              />
              <TextField
                label="Hora inicio"
                type="time"
                value={hora}
                onChange={(e) => setHora(e.target.value)}
                sx={{ flex: 1 }}
                InputLabelProps={{ shrink: true }}
              />
              <TextField
                label="Hora fin"
                type="time"
                value={horaFin}
                onChange={(e) => setHoraFin(e.target.value)}
                sx={{ flex: 1 }}
                InputLabelProps={{ shrink: true }}
              />
            </Stack>

            <Stack direction={{ xs: "column", sm: "row" }} spacing={2}>
              <TextField
                label="Color"
                type="color"
                value={color}
                onChange={(e) => setColor(e.target.value)}
                sx={{ width: { xs: "100%", sm: 150 } }}
                InputProps={{ sx: { p: 1.2 } }}
              />
              <TextField
                label="Notas"
                value={notas}
                onChange={(e) => setNotas(e.target.value)}
                multiline
                minRows={3}
                placeholder="Notas internas…"
                sx={{ flex: 1 }}
              />
            </Stack>
          </Stack>
        </DialogContent>

        <DialogActions sx={{ p: 3, pt: 0 }}>
          <Button onClick={closeDialog} disabled={sending}>
            Cancelar
          </Button>
          <Button variant="contained" onClick={handleSave} disabled={sending || !canSave}>
            {isEdit ? "Guardar cambios" : "Guardar"}
          </Button>
        </DialogActions>
      </Dialog>

      <Snackbar
        open={toast.open}
        autoHideDuration={2600}
        onClose={closeToast}
        anchorOrigin={{ vertical: "bottom", horizontal: "center" }}
      >
        <Alert onClose={closeToast} severity={toast.sev} variant="filled" sx={{ width: "100%" }}>
          {toast.msg}
        </Alert>
      </Snackbar>
    </>
  );
}

// Evita renders si no cambian props relevantes
function areEqual(prev, next) {
  if (prev.abierto !== next.abierto) return false;
  if (prev.modo !== next.modo) return false;
  const ac = prev.cliente ?? {};
  const bc = next.cliente ?? {};
  const ai = prev.cita ?? {};
  const bi = next.cita ?? {};

  if (ac === bc && ai === bi) return true;

  if (ac._id !== bc._id) return false;
  if (ac.nombre !== bc.nombre) return false;
  if (ac.telefono !== bc.telefono) return false;

  if (ai._id !== bi._id) return false;
  if (ai.title !== bi.title) return false;
  if (ai.date !== bi.date) return false;
  if (ai.hora !== bi.hora) return false;
  if (ai.horaFin !== bi.horaFin) return false;
  if (ai.color !== bi.color) return false;
  if (ai.notas !== bi.notas) return false;

  return true;
}

export default memo(DialogCita, areEqual);
