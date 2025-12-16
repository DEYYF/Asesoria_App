import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Button,
  Stack,
  Chip,
  Box,
  Typography,
  Snackbar,
  Alert,
} from "@mui/material";
import { useEffect, useMemo, useState, useCallback, memo } from "react";
import API from "../services/api";
import { useAuth } from "../context/AuthContext";
import { extractAsesorId } from "../utils/auth";

const isEmail = (e) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(e || "").trim());

function DialogCorreo({ abierto, onClose, cliente }) {
  const { user, token } = useAuth();
  const asesorId = useMemo(() => extractAsesorId(user, token), [user, token]);

  const [to, setTo] = useState("");
  const [subject, setSubject] = useState("");
  const [message, setMessage] = useState("");
  const [sending, setSending] = useState(false);
  const [toast, setToast] = useState({ open: false, sev: "success", msg: "" });

  useEffect(() => {
    if (abierto) {
      setTo(cliente?.email || "");
      setSubject("");
      setMessage(`Hola ${cliente?.nombre || ""},\n\n`);
    }
  }, [abierto, cliente?.email, cliente?.nombre]);

  const quickInsert = useCallback((type) => {
    if (type === "Bienvenida") {
      setSubject((s) => s || "Bienvenida a la asesoría");
      setMessage((m) =>
        m +
        "\nTe doy la bienvenida. En breve te compartiré tu planificación y accesos.\n\nCualquier duda, contesta a este correo."
      );
    } else if (type === "Cita") {
      setSubject((s) => s || "Propuesta de cita");
      setMessage((m) => m + "\n¿Te viene bien una llamada el jueves a las 18:00?\n");
    } else if (type === "Recordatorio") {
      setSubject((s) => s || "Recordatorio");
      setMessage((m) => m + "\nTe recuerdo que tenemos pendiente revisar tu progreso semanal.\n");
    }
  }, []);

  const closeToast = useCallback(
    () => setToast((p) => ({ ...p, open: false })),
    []
  );

  const handleSend = useCallback(async () => {
    if (!isEmail(to) || !subject.trim() || !message.trim()) {
      setToast({ open: true, sev: "warning", msg: "Completa destinatario, asunto y mensaje." });
      return;
    }
    setSending(true);
    try {
      await API.post("/correo/enviar", {
        asesorId: asesorId || null,
        destinatario: to,
        asunto: subject.trim(),
        mensaje: message,
        clienteId: cliente?._id,
      });

      setToast({ open: true, sev: "success", msg: "Correo enviado" });
      onClose?.();
    } catch (e) {
      console.error("POST /correo/enviar", e);
      setToast({ open: true, sev: "error", msg: "No se pudo enviar el correo" });
    } finally {
      setSending(false);
    }
  }, [to, subject, message, asesorId, cliente?._id, onClose]);

  return (
    <>
      <Dialog
        open={abierto}
        onClose={sending ? undefined : onClose}
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
            Enviar correo {cliente?.nombre ? `a ${cliente.nombre}` : ""}
          </DialogTitle>
          <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
            Redacta el mensaje y pulsa enviar.
          </Typography>
        </Box>

        <DialogContent sx={{ p: 3 }}>
          <Stack spacing={1.25}>
            <TextField
              label="Para"
              size="small"
              value={to}
              onChange={(e) => setTo(e.target.value)}
              error={!!to && !isEmail(to)}
              helperText={!!to && !isEmail(to) ? "Email no válido" : " "}
            />
            <TextField
              label="Asunto"
              size="small"
              value={subject}
              onChange={(e) => setSubject(e.target.value)}
              placeholder="Ej. Bienvenida, seguimiento semanal…"
            />

            <TextField
              label="Mensaje"
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              multiline
              minRows={8}
              placeholder="Escribe tu mensaje…"
              sx={{
                "& .MuiInputBase-root": {
                  borderRadius: 2,
                  background:
                    "linear-gradient(180deg, rgba(249,250,253,0.7) 0%, rgba(255,255,255,1) 40%)",
                },
              }}
              helperText={`${message.length}/1000`}
              inputProps={{ maxLength: 1000 }}
            />

            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
              <Chip label="Bienvenida" size="small" onClick={() => quickInsert("Bienvenida")} />
              <Chip label="Cita" size="small" onClick={() => quickInsert("Cita")} />
              <Chip label="Recordatorio" size="small" onClick={() => quickInsert("Recordatorio")} />
            </Stack>
          </Stack>
        </DialogContent>

        <DialogActions sx={{ p: 3, pt: 0 }}>
          <Button onClick={onClose} disabled={sending}>
            Cancelar
          </Button>
          <Button
            variant="contained"
            onClick={handleSend}
            disabled={sending || !to || !subject || !message}
          >
            Enviar
          </Button>
        </DialogActions>
      </Dialog>

      <Snackbar
        open={toast.open}
        autoHideDuration={2500}
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
  const a = prev.cliente ?? {};
  const b = next.cliente ?? {};
  if (prev.abierto !== next.abierto) return false;
  if (a === b) return true;
  if (a._id !== b._id) return false;
  if (a.email !== b.email) return false;
  if (a.nombre !== b.nombre) return false;
  return true;
}

export default memo(DialogCorreo, areEqual);
