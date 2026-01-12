import React, { useEffect, useState } from "react";
import {
  Box,
  Typography,
  Paper,
  Table,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  Chip,
  CircularProgress,
  IconButton,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Button,
  TextField,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Tabs,
  Tab,
  Grid
} from "@mui/material";
import EditIcon from "@mui/icons-material/Edit";
import PictureAsPdfIcon from "@mui/icons-material/PictureAsPdf";
import EmailIcon from "@mui/icons-material/Email";
import VisibilityIcon from "@mui/icons-material/Visibility";
import DeleteIcon from "@mui/icons-material/Delete";
import jsPDF from "jspdf";
import autoTable from "jspdf-autotable";
import API from "../services/api";
import { useAuth } from "../context/AuthContext";

const PresupuestosPage = () => {
  const { user } = useAuth();
  const [presupuestos, setPresupuestos] = useState([]);
  const [loading, setLoading] = useState(true);
  const [tabValue, setTabValue] = useState(0); // 0: Presupuestos, 1: Borradores
  const [groupByClient, setGroupByClient] = useState(true); // NEW: Toggle for grouping

  // Estado para edición
  const [openDialog, setOpenDialog] = useState(false);
  const [editingPresupuesto, setEditingPresupuesto] = useState(null);
  const [editDescuento, setEditDescuento] = useState(0);
  const [editEstado, setEditEstado] = useState("");

  // Estado para detalle (Vista Profesional)
  const [openDetailDialog, setOpenDetailDialog] = useState(false);
  const [detailPresupuesto, setDetailPresupuesto] = useState(null);

  // Estado para nuevo borrador
  const [openBorradorDialog, setOpenBorradorDialog] = useState(false);
  const [nuevoBorrador, setNuevoBorrador] = useState({
    nombreCliente: "",
    emailCliente: "",
    tarifaId: "",
    extras: [],
    fechaInicio: new Date().toISOString().split('T')[0],
  });

  const [tarifas, setTarifas] = useState([]);
  const [extras, setExtras] = useState([]);

  const fetchData = async () => {
    try {
      setLoading(true);

      const asesorId = user?._id || user?.id || user?.userId;

      const [resPresupuestos, resTarifas, resExtras] = await Promise.all([
        API.get(`/presupuestos?asesorId=${asesorId}`),
        API.get("/tarifas"),
        API.get("/extras"),
      ]);

      setPresupuestos(resPresupuestos.data);
      setTarifas(resTarifas.data);
      setExtras(resExtras.data);

    } catch (error) {
      console.error("Error fetching data:", error);
    } finally {
      setLoading(false);
    }
  };


  useEffect(() => {
    fetchData();
  }, []);

  const handleCreateBorrador = async () => {
    try {
      const { nombreCliente, emailCliente, tarifaId, extras: extrasIds, fechaInicio } = nuevoBorrador;
      if (!nombreCliente || !emailCliente || !tarifaId) {
        alert("Por favor completa los campos obligatorios");
        return;
      }

      // Try to get user ID from different possible fields
      let usuarioId = user?._id || user?.id || user?.userId;
      
      // If still no ID, try to decode from token
      if (!usuarioId) {
        const token = localStorage.getItem('app_token') || sessionStorage.getItem('app_token');
        if (token) {
          try {
            const payload = JSON.parse(atob(token.split('.')[1]));
            usuarioId = payload._id || payload.id || payload.userId || payload.sub;
          } catch (e) {
            console.error("Error decoding token:", e);
          }
        }
      }

      if (!usuarioId) {
        alert("Error: No se pudo obtener el ID del usuario. Por favor, recarga la página.");
        console.error("User object:", user);
        return;
      }

      const payload = {
        nombreCliente,
        emailCliente,
        tarifaId,
        extras: extrasIds,
        fechaInicio,
        usuarioId, 
      };

      console.log("Creating borrador with payload:", payload);

      await API.post("/presupuestos", payload);
      
      setOpenBorradorDialog(false);
      setNuevoBorrador({
        nombreCliente: "",
        emailCliente: "",
        tarifaId: "",
        extras: [],
        fechaInicio: new Date().toISOString().split('T')[0],
      });
      fetchData();
    } catch (error) {
      console.error("Error creating borrador:", error);
      console.error("Error response:", error.response?.data);
      alert(`Error al crear el borrador: ${error.response?.data?.message || error.message}`);
    }
  };

  const handleEdit = (p) => {
    setEditingPresupuesto(p);
    setEditDescuento(p.descuento || 0);
    setEditEstado(p.estado);
    setOpenDialog(true);
  };

  const handleDelete = async (p) => {
    if (!confirm(`¿Estás seguro de eliminar el presupuesto de ${p.clienteId?.nombre || p.nombreCliente}?`)) return;
    try {
      await API.delete(`/presupuestos/${p._id}`);
      fetchData();
    } catch (error) {
      console.error("Error deleting presupuesto:", error);
      alert("Error al eliminar el presupuesto");
    }
  };

  const handleViewDetail = (p) => {
    setDetailPresupuesto(p);
    setOpenDetailDialog(true);
  };

  const handleSave = async () => {
    try {
      await API.put(`/presupuestos/${editingPresupuesto._id}`, {
        descuento: Number(editDescuento),
        estado: editEstado,
      });
      setOpenDialog(false);
      fetchData(); // Recargar datos
    } catch (error) {
      console.error("Error updating presupuesto:", error);
      alert("Error al actualizar el presupuesto");
    }
  };

  const generatePDF = (p) => {
    const doc = new jsPDF();
    const primaryColor = [41, 128, 185]; // Blue professional
    
    // Header
    doc.setFontSize(26);
    doc.setTextColor(...primaryColor);
    doc.text("PRESUPUESTO", 14, 22);
    
    doc.setFontSize(10);
    doc.setTextColor(100);
    doc.text(`ID: ${p._id}`, 14, 30);
    doc.text(`Fecha: ${new Date(p.createdAt).toLocaleDateString()}`, 14, 35);

    // Cliente Info Box
    doc.setDrawColor(200);
    doc.setFillColor(250);
    doc.rect(14, 45, 182, 25, "FD");
    
    doc.setFontSize(11);
    doc.setTextColor(0);
    doc.setFont("helvetica", "bold");
    doc.text("Datos del Cliente:", 18, 52);
    doc.setFont("helvetica", "normal");
    doc.setFontSize(10);
    doc.text(p.clienteId?.nombre || p.nombreCliente || "N/A", 18, 59);
    doc.text(p.clienteId?.email || p.emailCliente || "", 18, 64);

    // Table Data
    const rows = [
      [p.tarifaId?.nombre || "Tarifa Base", `${p.tarifaId?.precio?.toFixed(2) || 0} €`],
    ];
    
    let subtotal = p.tarifaId?.precio || 0;

    // Calculate months from tariff duration
    const duracionDias = p.tarifaId?.duracionDias || 30;
    const meses = Math.ceil(duracionDias / 30);

    if (p.extras && p.extras.length > 0) {
      p.extras.forEach(e => {
        const precioMensual = e.precio || 0;
        const precioTotal = e.precioTotal || (precioMensual * meses);
        rows.push([
          `Extra: ${e.extraId?.nombre || "Extra"} (${precioMensual.toFixed(2)}€/mes × ${meses} meses)`, 
          `${precioTotal.toFixed(2)} €`
        ]);
        subtotal += precioTotal;
      });
    }

    // Calcular totales
    const descuentoValor = (subtotal * (p.descuento || 0)) / 100;
    const total = subtotal - descuentoValor;

    autoTable(doc, {
      startY: 80,
      head: [["CONCEPTO", "PRECIO"]],
      body: rows,
      theme: 'grid',
      headStyles: { fillColor: primaryColor, textColor: 255, fontStyle: 'bold' },
      styles: { fontSize: 10, cellPadding: 3 },
      columnStyles: { 1: { halign: 'right' } },
    });

    // Totales Section
    const finalY = doc.lastAutoTable.finalY + 10;
    const rightMargin = 196;
    
    doc.setFontSize(10);
    doc.text("Subtotal:", 140, finalY);
    doc.text(`${subtotal.toFixed(2)} €`, rightMargin, finalY, { align: "right" });
    
    if (p.descuento > 0) {
      doc.setTextColor(200, 0, 0);
      doc.text(`Descuento (${p.descuento}%):`, 140, finalY + 7);
      doc.text(`- ${descuentoValor.toFixed(2)} €`, rightMargin, finalY + 7, { align: "right" });
      doc.setTextColor(0);
    }

    doc.setFontSize(14);
    doc.setFont("helvetica", "bold");
    doc.text("TOTAL:", 140, finalY + 16);
    doc.setTextColor(...primaryColor);
    doc.text(`${total.toFixed(2)} €`, rightMargin, finalY + 16, { align: "right" });

    // Asesor y Company Info
    const infoY = finalY + 35;
    doc.setFontSize(9);
    doc.setTextColor(80);
    doc.setFont("helvetica", "normal");
    
    // Company Info (Left)
    doc.text("ASESORIA ENTERPRISE", 14, infoY);
    doc.text("asesoriaenterprise@gmail.com", 14, infoY + 5);
    
    // Asesor Info (Right)
    const asesorNombre = p.usuarioId?.nombre || user?.nombre || "Asesor";
    doc.text(`Asesorado por: ${asesorNombre}`, rightMargin, infoY, { align: "right" });

    // Footer
    doc.setFontSize(9);
    doc.setTextColor(100);
    doc.setFont("helvetica", "normal");
    doc.text("Gracias por confiar en nuestros servicios.", 105, 280, { align: "center" });

    return doc;
  };

  const handleDownloadPDF = (p) => {
    const doc = generatePDF(p);
    const name = p.clienteId?.nombre || p.nombreCliente || "Cliente";
    doc.save(`Presupuesto_${name.replace(/\s+/g, '_')}.pdf`);
  };

  const handleSendEmail = async (p) => {
    const email = p.clienteId?.email || p.emailCliente;
    const nombre = p.clienteId?.nombre || p.nombreCliente || "Cliente";

    if (!email) {
      alert("El presupuesto no tiene email asociado.");
      return;
    }
    
    if (!confirm(`¿Enviar presupuesto por email a ${email}?`)) return;

    try {
      // Generar PDF y convertir a Base64
      const doc = generatePDF(p);
      const pdfBlob = doc.output('blob');
      
      // Convertir Blob a Base64
      const reader = new FileReader();
      reader.readAsDataURL(pdfBlob);
      reader.onloadend = async () => {
        const base64data = reader.result.split(',')[1]; // Quitar prefijo "data:application/pdf;base64,"

        const htmlContent = `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #333;">Hola ${nombre},</h2>
            <p>Te dejamos por aqui el presupuesto de tu asesoria. Esperamos pronta respuesta.</p>
            <p>Un saludo.</p>
          </div>
        `;

        await API.post("/correo/enviar", {
          to: email,
          subject: "Tu Presupuesto - Asesoría",
          html: htmlContent,
          attachments: [
            {
              filename: `Presupuesto_${nombre.replace(/\s+/g, '_')}.pdf`,
              content: base64data,
              encoding: 'base64',
            }
          ]
        });
        
        alert("Email enviado correctamente con el PDF adjunto.");
      };
    } catch (error) {
      console.error("Error enviando email:", error);
      alert("Error al enviar el email.");
    }
  };

  if (loading) {
    return (
      <Box sx={{ display: "flex", justifyContent: "center", p: 4 }}>
        <CircularProgress />
      </Box>
    );
  }

  // Group presupuestos by client
  const groupedPresupuestos = () => {
    const filtered = presupuestos.filter(p => tabValue === 0 ? p.clienteId : !p.clienteId);
    
    if (!groupByClient) {
      return { ungrouped: filtered };
    }

    const grouped = {};
    filtered.forEach(p => {
      const clientKey = p.clienteId?._id || p.emailCliente || 'sin-cliente';
      const clientName = p.clienteId?.nombre || p.nombreCliente || "Desconocido";
      
      if (!grouped[clientKey]) {
        grouped[clientKey] = {
          clientName,
          clientEmail: p.clienteId?.email || p.emailCliente,
          presupuestos: []
        };
      }
      grouped[clientKey].presupuestos.push(p);
    });

    return grouped;
  };

  const grouped = groupedPresupuestos();

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center", mb: 3 }}>
        <Typography variant="h4" fontWeight={700}>
          Gestión de Presupuestos
        </Typography>
        <Box sx={{ display: 'flex', gap: 2 }}>
          <Button 
            variant={groupByClient ? "contained" : "outlined"}
            onClick={() => setGroupByClient(!groupByClient)}
            size="small"
          >
            {groupByClient ? "Vista Agrupada" : "Vista Lista"}
          </Button>
          {tabValue === 1 && (
            <Button variant="contained" onClick={() => setOpenBorradorDialog(true)}>
              Nuevo Borrador
            </Button>
          )}
        </Box>
      </Box>

      <Tabs value={tabValue} onChange={(e, v) => setTabValue(v)} sx={{ mb: 2 }}>
        <Tab label="Clientes Registrados" />
        <Tab label="Borradores (Potenciales)" />
      </Tabs>


      {groupByClient ? (
        // Grouped View
        <Box>
          {Object.entries(grouped).map(([clientKey, clientData]) => (
            <Paper key={clientKey} elevation={2} sx={{ mb: 3, borderRadius: 3, overflow: "hidden" }}>
              <Box sx={{ bgcolor: "#f5f5f5", p: 2, borderBottom: "1px solid #e0e0e0" }}>
                <Typography variant="h6" fontWeight={600}>
                  {clientData.clientName}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  {clientData.clientEmail}
                </Typography>
              </Box>
              <Table>
                <TableHead sx={{ bgcolor: "#fafafa" }}>
                  <TableRow>
                    <TableCell><strong>Tarifa</strong></TableCell>
                    <TableCell><strong>Fecha Inicio</strong></TableCell>
                    <TableCell><strong>Fecha Fin</strong></TableCell>
                    <TableCell><strong>Total</strong></TableCell>
                    <TableCell><strong>Descuento</strong></TableCell>
                    <TableCell><strong>Estado</strong></TableCell>
                    <TableCell><strong>Acciones</strong></TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {clientData.presupuestos.map((p) => (
                    <TableRow key={p._id} hover>
                      <TableCell>
                        {p.tarifaId?.nombre || "—"}
                        {p.extras?.length > 0 && (
                          <Typography variant="caption" display="block" color="text.secondary">
                            + {p.extras.length} extras
                          </Typography>
                        )}
                      </TableCell>
                      <TableCell>
                        {p.fechaInicio ? new Date(p.fechaInicio).toLocaleDateString() : "—"}
                      </TableCell>
                      <TableCell>
                        {p.fechaFin ? new Date(p.fechaFin).toLocaleDateString() : "—"}
                      </TableCell>
                      <TableCell>
                        <Typography fontWeight={600} color="primary">
                          {p.total} €
                        </Typography>
                      </TableCell>
                      <TableCell>
                        {p.descuento ? `${p.descuento} %` : "—"}
                      </TableCell>
                      <TableCell>
                        <Chip
                          label={p.estado}
                          size="small"
                          color={p.estado === "pagado" || p.estado === "aceptado" ? "success" : p.estado === "rechazado" ? "error" : "warning"}
                          variant="outlined"
                          sx={{ textTransform: "capitalize" }}
                        />
                      </TableCell>
                      <TableCell>
                        <IconButton size="small" onClick={() => handleViewDetail(p)} title="Ver Detalle">
                          <VisibilityIcon />
                        </IconButton>
                        <IconButton size="small" onClick={() => handleEdit(p)} title="Editar">
                          <EditIcon />
                        </IconButton>
                        <IconButton size="small" onClick={() => handleDelete(p)} title="Eliminar" color="error">
                          <DeleteIcon />
                        </IconButton>
                        <IconButton size="small" onClick={() => handleDownloadPDF(p)} title="Descargar PDF" color="primary">
                          <PictureAsPdfIcon />
                        </IconButton>
                        <IconButton size="small" onClick={() => handleSendEmail(p)} title="Enviar Email" color="secondary">
                          <EmailIcon />
                        </IconButton>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </Paper>
          ))}
          {Object.keys(grouped).length === 0 && (
            <Paper elevation={2} sx={{ p: 4, textAlign: "center", borderRadius: 3 }}>
              <Typography color="text.secondary">No hay presupuestos registrados.</Typography>
            </Paper>
          )}
        </Box>
      ) : (
        // Ungrouped View (Original Table)
        <Paper elevation={2} sx={{ borderRadius: 3, overflow: "hidden" }}>
          <Table>
            <TableHead sx={{ bgcolor: "#f5f5f5" }}>
              <TableRow>
                <TableCell><strong>{tabValue === 0 ? "Cliente" : "Interesado"}</strong></TableCell>
                <TableCell><strong>Tarifa</strong></TableCell>
                <TableCell><strong>Fecha Inicio</strong></TableCell>
                <TableCell><strong>Fecha Fin</strong></TableCell>
                <TableCell><strong>Total</strong></TableCell>
                <TableCell><strong>Descuento</strong></TableCell>
                <TableCell><strong>Estado</strong></TableCell>
                <TableCell><strong>Acciones</strong></TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {grouped.ungrouped?.map((p) => (
                <TableRow key={p._id} hover>
                  <TableCell>
                    <Typography variant="body2" fontWeight={600}>
                      {p.clienteId?.nombre || p.nombreCliente || "Desconocido"}
                    </Typography>
                    <Typography variant="caption" color="text.secondary">
                      {p.clienteId?.email || p.emailCliente || "Sin email"}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    {p.tarifaId?.nombre || "—"}
                    {p.extras?.length > 0 && (
                      <Typography variant="caption" display="block" color="text.secondary">
                        + {p.extras.length} extras
                      </Typography>
                    )}
                  </TableCell>
                  <TableCell>
                    {p.fechaInicio ? new Date(p.fechaInicio).toLocaleDateString() : "—"}
                  </TableCell>
                  <TableCell>
                    {p.fechaFin ? new Date(p.fechaFin).toLocaleDateString() : "—"}
                  </TableCell>
                  <TableCell>
                    <Typography fontWeight={600} color="primary">
                      {p.total} €
                    </Typography>
                  </TableCell>
                  <TableCell>
                    {p.descuento ? `${p.descuento} %` : "—"}
                  </TableCell>
                  <TableCell>
                    <Chip
                      label={p.estado}
                      size="small"
                      color={p.estado === "pagado" || p.estado === "aceptado" ? "success" : p.estado === "rechazado" ? "error" : "warning"}
                      variant="outlined"
                      sx={{ textTransform: "capitalize" }}
                    />
                  </TableCell>
                  <TableCell>
                    <IconButton size="small" onClick={() => handleViewDetail(p)} title="Ver Detalle">
                      <VisibilityIcon />
                    </IconButton>
                    <IconButton size="small" onClick={() => handleEdit(p)} title="Editar">
                      <EditIcon />
                    </IconButton>
                    <IconButton size="small" onClick={() => handleDelete(p)} title="Eliminar" color="error">
                      <DeleteIcon />
                    </IconButton>
                    <IconButton size="small" onClick={() => handleDownloadPDF(p)} title="Descargar PDF" color="primary">
                      <PictureAsPdfIcon />
                    </IconButton>
                    <IconButton size="small" onClick={() => handleSendEmail(p)} title="Enviar Email" color="secondary">
                      <EmailIcon />
                    </IconButton>
                  </TableCell>
                </TableRow>
              ))}
              {(!grouped.ungrouped || grouped.ungrouped.length === 0) && (
                <TableRow>
                  <TableCell colSpan={8} align="center" sx={{ py: 4 }}>
                    No hay presupuestos registrados.
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </Paper>
      )}

      {/* Dialog Nuevo Borrador */}
      <Dialog open={openBorradorDialog} onClose={() => setOpenBorradorDialog(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Nuevo Borrador (Potencial Cliente)</DialogTitle>
        <DialogContent sx={{ pt: 2 }}>
          <TextField
            fullWidth
            margin="normal"
            label="Nombre del Interesado"
            value={nuevoBorrador.nombreCliente}
            onChange={(e) => setNuevoBorrador({ ...nuevoBorrador, nombreCliente: e.target.value })}
          />
          <TextField
            fullWidth
            margin="normal"
            label="Email del Interesado"
            type="email"
            value={nuevoBorrador.emailCliente}
            onChange={(e) => setNuevoBorrador({ ...nuevoBorrador, emailCliente: e.target.value })}
          />
          <FormControl fullWidth margin="normal">
            <InputLabel>Tarifa</InputLabel>
            <Select
              value={nuevoBorrador.tarifaId}
              label="Tarifa"
              onChange={(e) => setNuevoBorrador({ ...nuevoBorrador, tarifaId: e.target.value })}
            >
              {tarifas.map((t) => (
                <MenuItem key={t._id} value={t._id}>
                  {t.nombre} ({t.precio}€)
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          <FormControl fullWidth margin="normal">
            <InputLabel>Extras</InputLabel>
            <Select
              multiple
              value={nuevoBorrador.extras}
              label="Extras"
              onChange={(e) => setNuevoBorrador({ ...nuevoBorrador, extras: e.target.value })}
              renderValue={(selected) => (
                <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 0.5 }}>
                  {selected.map((value) => {
                    const extra = extras.find(e => e._id === value);
                    return <Chip key={value} label={extra?.nombre} size="small" />;
                  })}
                </Box>
              )}
            >
              {extras.map((e) => (
                <MenuItem key={e._id} value={e._id}>
                  {e.nombre} (+{e.precio}€)
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          <TextField
            fullWidth
            margin="normal"
            label="Fecha Inicio Prevista"
            type="date"
            InputLabelProps={{ shrink: true }}
            value={nuevoBorrador.fechaInicio}
            onChange={(e) => setNuevoBorrador({ ...nuevoBorrador, fechaInicio: e.target.value })}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpenBorradorDialog(false)}>Cancelar</Button>
          <Button variant="contained" onClick={handleCreateBorrador}>
            Crear Borrador
          </Button>
        </DialogActions>
      </Dialog>

      {/* Dialog de Edición */}
      <Dialog open={openDialog} onClose={() => setOpenDialog(false)}>
        <DialogTitle>Editar Presupuesto</DialogTitle>
        <DialogContent sx={{ minWidth: 300, pt: 2 }}>
          <TextField
            fullWidth
            margin="normal"
            label="Descuento (%)"
            type="number"
            inputProps={{ min: 0, max: 100, step: 0.1 }}
            value={editDescuento}
            onChange={(e) => setEditDescuento(e.target.value)}
          />
          <FormControl fullWidth margin="normal">
            <InputLabel>Estado</InputLabel>
            <Select
              value={editEstado}
              label="Estado"
              onChange={(e) => setEditEstado(e.target.value)}
            >
              <MenuItem value="pendiente">Pendiente</MenuItem>
              <MenuItem value="aceptado">Aceptado</MenuItem>
              <MenuItem value="rechazado">Rechazado</MenuItem>
              <MenuItem value="pagado">Pagado</MenuItem>
            </Select>
          </FormControl>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpenDialog(false)}>Cancelar</Button>
          <Button variant="contained" onClick={handleSave}>
            Guardar
          </Button>
        </DialogActions>
      </Dialog>
      {/* Dialog Detalle Profesional */}
      <Dialog open={openDetailDialog} onClose={() => setOpenDetailDialog(false)} maxWidth="md" fullWidth>
        <DialogTitle sx={{ bgcolor: "#333", color: "#fff", display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Typography variant="h6">Detalle del Presupuesto</Typography>
          <Typography variant="caption">ID: {detailPresupuesto?._id}</Typography>
        </DialogTitle>
        <DialogContent sx={{ p: 4 }}>
          {detailPresupuesto && (
            <Box>
              <Grid container spacing={4} sx={{ mb: 4 }}>
                <Grid item xs={6}>
                  <Typography variant="overline" color="text.secondary">Cliente</Typography>
                  <Typography variant="h6" fontWeight={700}>
                    {detailPresupuesto.clienteId?.nombre || detailPresupuesto.nombreCliente || "N/A"}
                  </Typography>
                  <Typography variant="body2">{detailPresupuesto.clienteId?.email || detailPresupuesto.emailCliente}</Typography>
                </Grid>
                <Grid item xs={6} sx={{ textAlign: "right" }}>
                  <Typography variant="overline" color="text.secondary">Fecha</Typography>
                  <Typography variant="h6">{new Date(detailPresupuesto.createdAt).toLocaleDateString()}</Typography>
                  <Chip 
                    label={detailPresupuesto.estado} 
                    color={detailPresupuesto.estado === "pagado" ? "success" : "default"} 
                    sx={{ mt: 1, textTransform: "capitalize" }} 
                  />
                </Grid>
              </Grid>

              <Paper variant="outlined" sx={{ overflow: "hidden" }}>
                <Table>
                  <TableHead sx={{ bgcolor: "#f9f9f9" }}>
                    <TableRow>
                      <TableCell>Concepto</TableCell>
                      <TableCell align="right">Precio</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    <TableRow>
                      <TableCell>
                        <Typography fontWeight={600}>{detailPresupuesto.tarifaId?.nombre}</Typography>
                        <Typography variant="caption" color="text.secondary">Tarifa Base</Typography>
                      </TableCell>
                      <TableCell align="right">{detailPresupuesto.tarifaId?.precio} €</TableCell>
                    </TableRow>
                    {(() => {
                      const duracionDias = detailPresupuesto.tarifaId?.duracionDias || 30;
                      const meses = Math.ceil(duracionDias / 30);
                      let subtotalCalculado = detailPresupuesto.tarifaId?.precio || 0;
                      
                      return detailPresupuesto.extras?.map((e, i) => {
                        const precioMensual = e.precio || 0;
                        const precioTotal = e.precioTotal || (precioMensual * meses);
                        subtotalCalculado += precioTotal;
                        
                        return (
                          <TableRow key={i}>
                            <TableCell>
                              <Typography>Extra: {e.extraId?.nombre}</Typography>
                              <Typography variant="caption" color="text.secondary">
                                {precioMensual.toFixed(2)}€/mes × {meses} meses
                              </Typography>
                            </TableCell>
                            <TableCell align="right">{precioTotal.toFixed(2)} €</TableCell>
                          </TableRow>
                        );
                      }).concat(
                        detailPresupuesto.descuento > 0 ? (
                          <TableRow key="descuento">
                            <TableCell sx={{ color: "success.main" }}>Descuento ({detailPresupuesto.descuento}%)</TableCell>
                            <TableCell align="right" sx={{ color: "success.main" }}>
                              - {((subtotalCalculado * detailPresupuesto.descuento) / 100).toFixed(2)} €
                            </TableCell>
                          </TableRow>
                        ) : null
                      );
                    })()}
                    <TableRow sx={{ bgcolor: "#f5f5f5" }}>
                      <TableCell><Typography variant="h6">TOTAL</Typography></TableCell>
                      <TableCell align="right"><Typography variant="h6" color="primary">{detailPresupuesto.total.toFixed(2)} €</Typography></TableCell>
                    </TableRow>
                  </TableBody>
                </Table>
              </Paper>
            </Box>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpenDetailDialog(false)}>Cerrar</Button>
          <Button variant="contained" startIcon={<PictureAsPdfIcon />} onClick={() => handleDownloadPDF(detailPresupuesto)}>
            Descargar PDF
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default PresupuestosPage;
