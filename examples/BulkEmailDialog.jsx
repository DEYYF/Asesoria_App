import { useState } from "react";
import {
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  TextField,
  Typography,
} from "@mui/material";
import API from "../services/api";

const BulkEmailDialog = ({ open, onClose, clientes, onSuccess, onError }) => {
  const [emailSubject, setEmailSubject] = useState("");
  const [emailMessage, setEmailMessage] = useState("");
  const [sendingEmails, setSendingEmails] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);

  const handleSendClick = () => {
    if (!emailSubject.trim() || !emailMessage.trim()) {
      onError?.("Por favor completa el asunto y el mensaje");
      return;
    }

    const clientsToEmail = clientes.filter((c) => c.email);
    if (clientsToEmail.length === 0) {
      onError?.("No hay clientes con email en la lista actual");
      return;
    }

    // Show confirmation dialog
    setConfirmOpen(true);
  };

  const handleConfirmSend = async () => {
    setConfirmOpen(false);
    setSendingEmails(true);

    const clientsToEmail = clientes.filter((c) => c.email);

    try {
      // Get all client emails
      const emailAddresses = clientsToEmail.map(c => c.email);

      // Send one email with all recipients in BCC
      await API.post("/correo/enviar", {
        to: emailAddresses[0], // First email as main recipient
        bcc: emailAddresses.slice(1), // Rest as BCC
        subject: emailSubject,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #333;">Hola,</h2>
            <div style="white-space: pre-wrap;">${emailMessage}</div>
            <br/>
            <p style="color: #666; font-size: 12px;">Este email fue enviado desde Asesoría Enterprise</p>
          </div>
        `,
      });

      onSuccess?.(`Email enviado correctamente a ${clientsToEmail.length} clientes`);

      // Reset and close
      setEmailSubject("");
      setEmailMessage("");
      onClose();
    } catch (error) {
      console.error("Error sending bulk email:", error);
      onError?.("Error al enviar el email");
    } finally {
      setSendingEmails(false);
    }
  };

  const handleClose = () => {
    if (!sendingEmails) {
      setEmailSubject("");
      setEmailMessage("");
      onClose();
    }
  };

  const clientsWithEmail = clientes.filter((c) => c.email).length;

  return (
    <>
      <Dialog open={open} onClose={handleClose} maxWidth="sm" fullWidth>
        <DialogTitle>Enviar Email a Todos los Clientes</DialogTitle>
        <DialogContent sx={{ pt: 2 }}>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Se enviará un email individual a {clientsWithEmail} clientes con email.
          </Typography>
          <TextField
            fullWidth
            margin="normal"
            label="Asunto"
            value={emailSubject}
            onChange={(e) => setEmailSubject(e.target.value)}
            disabled={sendingEmails}
          />
          <TextField
            fullWidth
            margin="normal"
            label="Mensaje"
            multiline
            rows={8}
            value={emailMessage}
            onChange={(e) => setEmailMessage(e.target.value)}
            disabled={sendingEmails}
            helperText="Se enviará un único email a todos los clientes seleccionados"
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={handleClose} disabled={sendingEmails}>
            Cancelar
          </Button>
          <Button
            variant="contained"
            onClick={handleSendClick}
            disabled={sendingEmails || !emailSubject.trim() || !emailMessage.trim()}
          >
            {sendingEmails ? "Enviando..." : "Enviar Emails"}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Confirmation Dialog */}
      <Dialog open={confirmOpen} onClose={() => setConfirmOpen(false)} maxWidth="xs" fullWidth>
        <DialogTitle>Confirmar Envío</DialogTitle>
        <DialogContent>
          <Typography>
            ¿Estás seguro de que deseas enviar este email a {clientsWithEmail} clientes?
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setConfirmOpen(false)} color="inherit">
            Cancelar
          </Button>
          <Button onClick={handleConfirmSend} variant="contained" color="primary">
            Confirmar y Enviar
          </Button>
        </DialogActions>
      </Dialog>
    </>
  );
};

export default BulkEmailDialog;
