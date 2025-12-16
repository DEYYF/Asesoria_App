// src/pages/VistaEntrenamiento.jsx
import { useEffect, useMemo, useState } from "react";
import {
  Box,
  Paper,
  Stack,
  Typography,
  Button,
  Chip,
  Grid,
  Table,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  Divider,
  IconButton,
  Tooltip,
  Skeleton,
  Alert,
  Snackbar,
  Accordion,
  AccordionSummary,
  AccordionDetails,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
} from "@mui/material";

import jsPDF from "jspdf";
import autoTable from "jspdf-autotable";
import html2canvas from "html2canvas";

import ArrowBackIcon from "@mui/icons-material/ArrowBack";
import EditIcon from "@mui/icons-material/Edit";
import PictureAsPdfIcon from "@mui/icons-material/PictureAsPdf";
import ContentCopyIcon from "@mui/icons-material/ContentCopy";
import DeleteForeverIcon from "@mui/icons-material/DeleteForever";
import ExpandMoreIcon from "@mui/icons-material/ExpandMore";
import FitnessCenterIcon from "@mui/icons-material/FitnessCenter";
import FlagIcon from "@mui/icons-material/Flag";
import EventIcon from "@mui/icons-material/Event";
import TimerIcon from "@mui/icons-material/Timer";
import MenuBookIcon from "@mui/icons-material/MenuBook";

import { useNavigate, useParams } from "react-router-dom";
import API from "../services/api";

const headerGradient =
  "linear-gradient(180deg, rgba(246,247,251,0.7) 0%, rgba(255,255,255,1) 45%)";

const fmt = (n, d = 0) =>
  typeof n === "number" ? Number(n.toFixed(d)).toLocaleString() : n ?? "—";

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

export default function VistaEntrenamiento() {
  const { id } = useParams();
  const navigate = useNavigate();

  const [ent, setEnt] = useState(null);
  const [loading, setLoading] = useState(true);
  const [toast, setToast] = useState({ open: false, sev: "success", msg: "" });

  // 🔴 Estado para eliminar
  const [openDelete, setOpenDelete] = useState(false);
  const [deleting, setDeleting] = useState(false);

  // Cargar entrenamiento por ID (espera populate de ejercicios en el back)
  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        setLoading(true);
        const res = await API.get(`/entrenamientos/${id}`);
        if (!mounted) return;
        setEnt(res.data || null);
      } catch (e) {
        console.error("GET /entrenamientos/:id", e);
        if (!mounted) return;
        setEnt(null);
        setToast({ open: true, sev: "error", msg: "No se pudo cargar el entrenamiento" });
      } finally {
        if (mounted) setLoading(false);
      }
    })();
    return () => { mounted = false; };
  }, [id]);

  // Contadores rápidos
  const counts = useMemo(() => {
    if (!ent?.semanas) return { semanas: 0, dias: 0, items: 0 };
    const semanas = ent.semanas.length;
    const dias = ent.semanas.reduce((acc, s) => acc + (s?.dias?.length || 0), 0);
    const items = ent.semanas.reduce(
      (acc, s) =>
        acc +
        (s?.dias || []).reduce((acc2, d) => acc2 + (d?.items?.length || 0), 0),
      0
    );
    return { semanas, dias, items };
  }, [ent]);

  const fechaStr = useMemo(() => {
    const f = ent?.updatedAt || ent?.createdAt;
    return f ? new Date(f).toLocaleDateString() : "—";
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ent?.updatedAt, ent?.createdAt]);

  const duplicar = async () => {
    try {
      if (!ent) return;
      const payload = JSON.parse(JSON.stringify(ent));
      // limpiar ids y fechas
      delete payload._id;
      delete payload.createdAt;
      delete payload.updatedAt;
      payload.titulo = `${payload.titulo || "Entrenamiento"} (copia)`;
      // limpiar _id internos si existen
      (payload.semanas || []).forEach((s) => {
        delete s._id;
        (s.dias || []).forEach((d) => {
          delete d._id;
          (d.items || []).forEach((it) => {
            delete it._id;
          });
        });
      });
      const res = await API.post("/entrenamientos", payload);
      setToast({ open: true, sev: "success", msg: "Entrenamiento duplicado" });
      navigate(`/entrenamiento/${res.data?._id}`);
    } catch (e) {
      console.error("Duplicar entrenamiento", e);
      setToast({ open: true, sev: "error", msg: "No se pudo duplicar" });
    }
  };

  // 🗑️ Eliminar entrenamiento
  const eliminar = async () => {
    try {
      setDeleting(true);
      await API.delete(`/entrenamientos/${id}`);
      setOpenDelete(false);
      setToast({ open: true, sev: "success", msg: "Entrenamiento eliminado" });
      // Redirigir: si hay cliente en localStorage → a su página; si no, volver atrás
      const clienteId = localStorage.getItem("cliente");
      if (clienteId) {
        navigate(`/clientes/${clienteId}`);
      } else {
        navigate(-1);
      }
    } catch (e) {
      console.error("DELETE /entrenamientos/:id", e);
      const msg = e?.response?.data?.error || "No se pudo eliminar";
      setToast({ open: true, sev: "error", msg });
    } finally {
      setDeleting(false);
    }
  };

  // 🖨️ Export PDF
  const handleExportPDF = () => {
    if (!ent) return;

    const doc = new jsPDF({
      orientation: "landscape",
      unit: "pt",
      format: "a4",
    });

    const pageW = doc.internal.pageSize.getWidth();
    const M = 28;
    const headFill = [25, 118, 210]; // Primary blue
    const textMain = [51, 51, 51];
    const gridLine = [220, 220, 220];

    // Header
    doc.setFillColor(...headFill);
    doc.rect(0, 0, pageW, 10, "F"); // Thin header bar
    
    doc.setTextColor(...textMain);
    doc.setFont("helvetica", "bold");
    doc.setFontSize(18);
    doc.text(ent.titulo || "Entrenamiento", M, 40);
    
    doc.setFont("helvetica", "normal");
    doc.setFontSize(10);
    doc.text(`Objetivo: ${ent.objetivo || "—"}`, M, 56);
    doc.text(`Actualizado: ${fechaStr}`, M, 68);

    let y = 90;

    // Iterate Semanas
    (ent.semanas || []).forEach((sem, sIdx) => {
        // Check space for Week header
        if (y > doc.internal.pageSize.getHeight() - 40) {
            doc.addPage();
            y = 40;
        }

        doc.setFont("helvetica", "bold");
        doc.setFontSize(14);
        doc.setTextColor(...headFill); // Blue header for weeks
        doc.text(`Semana ${sem.numero || sIdx + 1}`, M, y);
        y += 20;

        // Iterate Dias
        (sem.dias || []).forEach((dia, dIdx) => {
             // Check space for Day header and table
             if (y > doc.internal.pageSize.getHeight() - 60) {
                doc.addPage();
                y = 40;
            }

            doc.setFont("helvetica", "bold");
            doc.setFontSize(12);
            doc.setTextColor(0, 0, 0);
            doc.text(dia.nombre || `Día ${dIdx + 1}`, M, y);
            y += 10;

            const rows = (dia.items || []).map((it) => {
                const ex = it.ejercicio;
                const nombre = typeof ex === "object" && ex ? ex.nombre : (it.ejercicioNombre || "Ejercicio");
                const grupo = typeof ex === "object" && ex?.grupo ? ex.grupo : "";
                
                const series = fmt(it.esquema?.series);
                const reps = it.esquema?.repsMin != null && it.esquema?.repsMax != null
                    ? `${fmt(it.esquema.repsMin)}-${fmt(it.esquema.repsMax)}`
                    : "—";
                const rir = it.esquema?.rir != null ? fmt(it.esquema.rir) : "—";
                const descanso = it.esquema?.descanso != null ? `${fmt(it.esquema.descanso)}s` : "—";
                const notas = it.esquema?.notas || "";

                return [nombre, grupo, series, reps, rir, descanso, notas];
            });

             if (rows.length === 0) {
                 doc.setFont("helvetica", "italic");
                 doc.setFontSize(10);
                 doc.setTextColor(100);
                 doc.text("(Sin ejercicios)", M, y + 10);
                 y += 30;
                 return;
             }

             autoTable(doc, {
                startY: y,
                margin: { left: M, right: M },
                head: [["Ejercicio", "Grupo", "Series", "Reps", "RIR", "Descanso", "Notas"]],
                body: rows,
                theme: 'grid',
                styles: { fontSize: 9, cellPadding: 4, lineColor: gridLine, textColor: textMain },
                headStyles: { fillColor: headFill, textColor: [255, 255, 255], fontStyle: "bold" },
                columnStyles: {
                    0: { cellWidth: 160, fontStyle: 'bold' }, // Nombre
                    1: { cellWidth: 70 }, // Grupo
                    2: { cellWidth: 40, halign: 'center' }, // Series
                    3: { cellWidth: 50, halign: 'center' }, // Reps
                    4: { cellWidth: 40, halign: 'center' }, // RIR
                    5: { cellWidth: 50, halign: 'center' }, // Descanso
                    6: { cellWidth: 'auto' } // Notas
                },
             });
             
             y = doc.lastAutoTable.finalY + 25;
        });
        
        y += 10; // Extra space between weeks
    });

    doc.save(`entrenamiento_${ent.titulo.replace(/\s+/g, '_')}.pdf`);
  };

  // --------- UI ----------
  return (
    <Box p={{ xs: 2, md: 4 }}>
      {/* HEADER */}
      <Paper
        elevation={0}
        sx={{
          p: { xs: 2, md: 3 },
          mb: 3,
          borderRadius: 3,
          border: "1px solid",
          borderColor: "divider",
          background: headerGradient,
        }}
      >
        {loading ? (
          <Stack spacing={1}>
            <Skeleton width="30%" height={36} />
            <Skeleton width="55%" />
            <Stack direction="row" spacing={1}>
              <Skeleton variant="rounded" width={110} height={28} />
              <Skeleton variant="rounded" width={110} height={28} />
              <Skeleton variant="rounded" width={110} height={28} />
            </Stack>
          </Stack>
        ) : ent ? (
          <>
            <Stack
              direction={{ xs: "column", md: "row" }}
              alignItems={{ xs: "flex-start", md: "center" }}
              justifyContent="space-between"
              spacing={1.5}
            >
              <Stack spacing={0.5}>
                <Stack direction="row" spacing={1} alignItems="center">
                  <FitnessCenterIcon />
                  <Typography variant="h5" fontWeight={800}>
                    {ent.titulo || "Entrenamiento"}
                  </Typography>
                </Stack>
                <Typography variant="body2" color="text.secondary">
                  {ent.objetivo || "—"}
                </Typography>
              </Stack>

              <Stack direction="row" spacing={1} useFlexGap flexWrap="wrap">
                <Button
                  variant="outlined"
                  startIcon={<ArrowBackIcon />}
                  onClick={() => navigate(-1)}
                  sx={{ textTransform: "none" }}
                >
                  Volver
                </Button>
                <Button
                  variant="outlined"
                  startIcon={<EditIcon />}
                  onClick={() => navigate(`/entrenamiento/editar/${ent._id}`)}
                  sx={{ textTransform: "none" }}
                >
                  Editar
                </Button>
                <Button
                  variant="outlined"
                  startIcon={<ContentCopyIcon />}
                  onClick={duplicar}
                  sx={{ textTransform: "none" }}
                >
                  Duplicar
                </Button>
                {/* 🔴 Botón Eliminar */}
                <Button
                  variant="outlined"
                  color="error"
                  startIcon={<DeleteForeverIcon />}
                  onClick={() => setOpenDelete(true)}
                  sx={{ textTransform: "none" }}
                >
                  Eliminar
                </Button>
                <Button
                  variant="contained"
                  startIcon={<PictureAsPdfIcon />}
                  onClick={handleExportPDF}
                  sx={{ textTransform: "none" }}
                >
                  Exportar PDF
                </Button>
                {/* 📔 Botón Notebook */}
                <Button
                  variant="contained"
                  color="secondary"
                  startIcon={<MenuBookIcon />}
                  onClick={() => navigate(`/entrenamiento/cuaderno/${ent._id}`)}
                  sx={{ textTransform: "none" }}
                >
                  Registrar Sesión
                </Button>
              </Stack>
            </Stack>

            <Stack direction="row" spacing={1} mt={1.25} flexWrap="wrap" useFlexGap>
              <Chip
                icon={<EventIcon sx={{ fontSize: 18 }} />}
                label={`Actualizado: ${fechaStr}`}
                size="small"
                variant="outlined"
                sx={{ borderRadius: 2 }}
              />
              <Chip
                icon={<FlagIcon sx={{ fontSize: 18 }} />}
                label={`${fmt(counts.semanas)} semana${counts.semanas === 1 ? "" : "s"}`}
                size="small"
                variant="outlined"
                sx={{ borderRadius: 2 }}
              />
              <Chip
                icon={<FlagIcon sx={{ fontSize: 18 }} />}
                label={`${fmt(counts.dias)} día${counts.dias === 1 ? "" : "s"}`}
                size="small"
                variant="outlined"
                sx={{ borderRadius: 2 }}
              />
              <Chip
                icon={<FitnessCenterIcon sx={{ fontSize: 18 }} />}
                label={`${fmt(counts.items)} ejercicio${counts.items === 1 ? "" : "s"}`}
                size="small"
                sx={{ borderRadius: 2 }}
              />
              {ent?.activo === false && (
                <Chip color="warning" label="Inactivo" size="small" sx={{ borderRadius: 2 }} />
              )}
            </Stack>
          </>
        ) : (
          <Typography color="error">No se encontró el entrenamiento.</Typography>
        )}
      </Paper>

      {/* CONTENIDO */}
      {loading && (
        <Grid container spacing={2}>
          {Array.from({ length: 2 }).map((_, i) => (
            <Grid item xs={12} key={i}>
              <Paper elevation={0} sx={{ p: 2, borderRadius: 3, border: "1px solid", borderColor: "divider" }}>
                <Skeleton width="30%" />
                <Divider sx={{ my: 2 }} />
                {Array.from({ length: 3 }).map((__, j) => (
                  <Skeleton key={j} height={36} sx={{ mb: 1 }} />
                ))}
              </Paper>
            </Grid>
          ))}
        </Grid>
      )}

      {!loading && ent && (
        <Stack spacing={2}>
          {(ent.semanas || []).map((sem, si) => (
            <Paper
              key={si}
              elevation={0}
              sx={{
                p: 2,
                borderRadius: 3,
                border: "1px solid",
                borderColor: "divider",
              }}
            >
              <Stack direction="row" justifyContent="space-between" alignItems="center">
                <Typography variant="h6" fontWeight={800}>
                  Semana {sem.numero || si + 1}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  {(sem.dias || []).length} día(s)
                </Typography>
              </Stack>

              <Divider sx={{ my: 1.5 }} />

              {(sem.dias || []).map((dia, di) => (
                <Accordion key={di} sx={{ borderRadius: 2, mb: 1, overflow: "hidden" }} defaultExpanded>
                  <AccordionSummary expandIcon={<ExpandMoreIcon />}>
                    <Stack
                      direction={{ xs: "column", sm: "row" }}
                      spacing={1}
                      alignItems={{ xs: "flex-start", sm: "center" }}
                      justifyContent="space-between"
                      sx={{ width: "100%" }}
                    >
                      <Typography fontWeight={700}>{dia.nombre || `Día ${di + 1}`}</Typography>
                      <Chip
                        size="small"
                        variant="outlined"
                        label={`${dia.items?.length || 0} ejercicio(s)`}
                        sx={{ borderRadius: 2 }}
                      />
                    </Stack>
                  </AccordionSummary>
                  <AccordionDetails sx={{ pt: 0 }}>
                    <Paper variant="outlined" sx={{ borderRadius: 2, overflow: "hidden" }}>
                      <Table size="small">
                        <TableHead>
                          <TableRow sx={{ backgroundColor: "rgba(0,0,0,0.02)" }}>
                            <TableCell sx={{ fontWeight: 700 }}>Ejercicio</TableCell>
                            <TableCell align="center">Series</TableCell>
                            <TableCell align="center">Reps</TableCell>
                            <TableCell align="center" title="Reps en recámara">RIR</TableCell>
                            <TableCell align="center">Descanso (s)</TableCell>
                            <TableCell>Notas</TableCell>
                            <TableCell width={120}>Grupo</TableCell>
                            <TableCell width={180}>Video</TableCell>
                          </TableRow>
                        </TableHead>
                        <TableBody>
                          {(dia.items || []).map((it, ii) => {
                            const ex = it?.ejercicio; // populate → objeto; si no → id
                            const nombre =
                              typeof ex === "object" && ex
                                ? ex.nombre
                                : (it?.ejercicioNombre || "Ejercicio");
                            const urlVideo =
                              typeof ex === "object" && ex ? ex.urlVideo : it?.urlVideo;
                            const reps =
                              it?.esquema?.repsMin != null && it?.esquema?.repsMax != null
                                ? `${fmt(it.esquema.repsMin)} - ${fmt(it.esquema.repsMax)}`
                                : "—";
                            const videoEmbed = urlVideo && youtubeId(urlVideo);

                            return (
                              <TableRow key={ii}>
                                <TableCell sx={{ fontWeight: 600 }}>
                                  {nombre}
                                  {typeof ex === "object" && ex?.grupo && (
                                    <Chip label={ex.grupo} size="small" sx={{ ml: 1, borderRadius: 2 }} />
                                  )}
                                  {typeof ex === "object" && ex?.equipo && (
                                    <Chip label={ex.equipo} size="small" variant="outlined" sx={{ ml: 1, borderRadius: 2 }} />
                                  )}
                                </TableCell>
                                <TableCell align="center">{fmt(it?.esquema?.series)}</TableCell>
                                <TableCell align="center">{reps}</TableCell>
                                <TableCell align="center">
                                  {it?.esquema?.rir != null ? fmt(it.esquema.rir) : "—"}
                                </TableCell>
                                <TableCell align="center">
                                  {it?.esquema?.descanso != null ? fmt(it.esquema.descanso) : "—"}
                                </TableCell>
                                <TableCell>{it?.esquema?.notas || "—"}</TableCell>
                                <TableCell>{it?.grupoId || "—"}</TableCell>
                                <TableCell>
                                  {videoEmbed ? (
                                    <Box
                                      sx={{
                                        position: "relative",
                                        pt: "56.25%",
                                        borderRadius: 1,
                                        overflow: "hidden",
                                      }}
                                    >
                                      <iframe
                                        title={`video-${si}-${di}-${ii}`}
                                        src={`https://www.youtube.com/embed/${videoEmbed}`}
                                        style={{
                                          position: "absolute",
                                          inset: 0,
                                          width: "100%",
                                          height: "100%",
                                          border: 0,
                                        }}
                                        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                                        allowFullScreen
                                      />
                                    </Box>
                                  ) : urlVideo ? (
                                    <Tooltip title="Abrir video" arrow>
                                      <a
                                        href={urlVideo}
                                        rel="noopener noreferrer"
                                        target="_blank"
                                        style={{ textDecoration: "none" }}
                                      >
                                        Ver video
                                      </a>
                                    </Tooltip>
                                  ) : (
                                    "—"
                                  )}
                                </TableCell>
                              </TableRow>
                            );
                          })}
                          {(dia.items || []).length === 0 && (
                            <TableRow>
                              <TableCell colSpan={8}>
                                <Box p={2} textAlign="center" color="text.secondary">
                                  No hay ejercicios en este día.
                                </Box>
                              </TableCell>
                            </TableRow>
                          )}
                        </TableBody>
                      </Table>
                    </Paper>
                  </AccordionDetails>
                </Accordion>
              ))}
            </Paper>
          ))}
        </Stack>
      )}

      {/* DIALOG ELIMINAR */}
      <Dialog open={openDelete} onClose={() => setOpenDelete(false)} maxWidth="xs" fullWidth>
        <DialogTitle sx={{ fontWeight: 800 }}>Eliminar entrenamiento</DialogTitle>
        <DialogContent dividers>
          ¿Seguro que deseas eliminar <strong>{ent?.titulo || "este entrenamiento"}</strong>? Esta acción no se puede deshacer.
        </DialogContent>
        <DialogActions sx={{ p: 2 }}>
          <Button onClick={() => setOpenDelete(false)}>Cancelar</Button>
          <Button
            color="error"
            variant="contained"
            startIcon={<DeleteForeverIcon />}
            onClick={eliminar}
            disabled={deleting}
          >
            {deleting ? "Eliminando..." : "Eliminar"}
          </Button>
        </DialogActions>
      </Dialog>

      {/* TOAST */}
      <Snackbar
        open={toast.open}
        autoHideDuration={3000}
        onClose={() => setToast((t) => ({ ...t, open: false }))}
        anchorOrigin={{ vertical: "bottom", horizontal: "right" }}
      >
        <Alert
          severity={toast.sev}
          onClose={() => setToast((t) => ({ ...t, open: false }))}
          variant="filled"
          sx={{ width: "100%" }}
        >
          {toast.msg}
        </Alert>
      </Snackbar>
    </Box>
  );
}
