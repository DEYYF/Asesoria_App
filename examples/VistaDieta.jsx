import { useEffect, useMemo, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
  Box,
  Typography,
  Button,
  Paper,
  Divider,
  Stack,
  Chip,
  Grid,
  Card,
  CardContent,
  Tooltip,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogContentText,
  DialogActions,
  useTheme,
  useMediaQuery,
} from "@mui/material";
import { useAuth } from "../context/AuthContext";
import { extractAsesorId } from "../utils/auth";

import CalendarMonthIcon from "@mui/icons-material/CalendarMonth";
import LocalFireDepartmentIcon from "@mui/icons-material/LocalFireDepartment";
import EggAltIcon from "@mui/icons-material/EggAlt";
import BakeryDiningIcon from "@mui/icons-material/BakeryDining";
import OpacityIcon from "@mui/icons-material/Opacity";
import FlagIcon from "@mui/icons-material/Flag";
import EditIcon from "@mui/icons-material/Edit";
import DeleteOutlineIcon from "@mui/icons-material/DeleteOutline";
import PictureAsPdfIcon from "@mui/icons-material/PictureAsPdf";
import SaveAsIcon from "@mui/icons-material/SaveAs";
import HistoryIcon from "@mui/icons-material/History";

import API from "../services/api";
import ComidasDieta from "../components/Dieta/ComidasDieta";
import RevisionsDialog from "../components/RevisionsDialog";
import { createRevision } from "../services/dietas";

import jsPDF from "jspdf";
import autoTable from "jspdf-autotable";

const fmt = (n, d = 2) =>
  typeof n === "number" ? Number(n.toFixed(d)).toLocaleString() : n ?? "-";

const VistaDieta = () => {
  const { id } = useParams();
  const { user, token } = useAuth();
  const asesorId = useMemo(() => extractAsesorId(user, token), [user, token]);
  const navigate = useNavigate();

  const theme = useTheme();
  const isXs = useMediaQuery(theme.breakpoints.down("sm"));

  const [dieta, setDieta] = useState(null);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [openRevisions, setOpenRevisions] = useState(false);

  const fetchDieta = async (customId) => {
    const targetId = customId || id;
    try {
      const res = await API.get(`/dietas/${targetId}`);
      // The 'getById' endpoint already populates 'comidas' with 'recetaId' details.
      // No need to fetch /comidas separately (which returns unpopulated data).
      setDieta(res.data);
    } catch (err) {
      console.error("Error al cargar la dieta", err);
    }
  };

  const handleEliminar = async () => {
    try {
      await API.delete(`/dietas/${id}`);
      navigate(-1);
    } catch (err) {
      console.error("Error al eliminar la dieta", err);
    }
  };

  useEffect(() => {
    fetchDieta();
  }, [id]);

  const fechaCreacion = useMemo(
    () =>
      dieta?.createdAt
        ? new Date(dieta.createdAt).toLocaleDateString()
        : "-",
    [dieta]
  );

  const macrosKcal = useMemo(() => {
    if (!dieta?.macros) return null;
    const p = Number(dieta.macros.p || 0) * 4;
    const c = Number(dieta.macros.c || 0) * 4;
    const g = Number(dieta.macros.g || 0) * 9;
    return { p, c, g, total: p + c + g };
  }, [dieta]);

  const handleExportPDF = () => {
    if (!dieta) return;

    const doc = new jsPDF({
      orientation: "landscape",
      unit: "pt",
      format: "a4",
    });

    const pageW = doc.internal.pageSize.getWidth();
    const pageH = doc.internal.pageSize.getHeight();
    const M = 28;

    const headFill = [255, 224, 178];
    const textMain = [51, 51, 51];
    const gridLine = [220, 220, 220];

    const fecha = fechaCreacion;
    const kcalObj = fmt(dieta?.macros?.kcal || 0, 0);

    // Header
    doc.setFillColor(255, 183, 77);
    doc.rect(0, 0, pageW, 8, "F");
    doc.setTextColor(...textMain);
    doc.setFont("helvetica", "bold");
    doc.setFontSize(16);
    doc.text(`Dieta · ${kcalObj} kcal · ${fecha}`, M, 30);
    doc.setFont("helvetica", "normal");
    doc.setFontSize(10);
    doc.text("Detalle de la dieta", M, 46);

    // Macros table
    autoTable(doc, {
      startY: 70,
      margin: { left: M, right: M, top: 60 },
      styles: {
        fontSize: 10,
        cellPadding: 6,
        lineColor: gridLine,
        lineWidth: 0.6,
        halign: "center",
        valign: "middle",
        textColor: textMain,
      },
      head: [["Proteínas (g)", "Carbohidratos (g)", "Grasas (g)"]],
      body: [
        [
          fmt(dieta?.macros?.p, 0),
          fmt(dieta?.macros?.c, 0),
          fmt(dieta?.macros?.g, 0),
        ],
      ],
      theme: "grid",
      headStyles: {
        fillColor: headFill,
        textColor: [0, 0, 0],
        fontStyle: "bold",
      },
      bodyStyles: { fillColor: [255, 255, 255], fontStyle: "bold" },
    });

    let y = doc.lastAutoTable?.finalY ? doc.lastAutoTable.finalY + 18 : 100;

    // Comidas
    (dieta.comidas || []).forEach((comida, cIdx) => {
      const ensureSpace = (minSpace = 120) => {
        const h = doc.internal.pageSize.getHeight();
        if (y + minSpace > h - M) {
          doc.addPage();
          y = 70;
        }
      };

      ensureSpace(120);

      doc.setFont("helvetica", "bold");
      doc.setFontSize(12);
      doc.setTextColor(...textMain);
      doc.text(comida.titulo || `Comida ${cIdx + 1}`, M, y);
      y += 8;

      const rows = (comida.opciones || []).map((op, i) => {
        // Logic to extract ingredients (mirrors ComidasDieta.jsx)
        let items = [];
        if (op.tipo === "receta" && op.recetaId && typeof op.recetaId === "object") {
             if (Array.isArray(op.recetaId.ingredientes)) {
                 items = op.recetaId.ingredientes.map(ri => ({
                     nombre: ri.ingrediente?.nombre || "Ingrediente",
                     gramos: ri.gramos
                 }));
             }
        } else {
             items = op.items || op.ingredientes || [];
        }

        const ingredientesText = items
          .map((ing) => `${ing.nombre || "-"} (${fmt(Number(ing.gramos ?? 0), 0)} gr)`)
          .join(", ");

        let name = op.nombre || "Sin nombre";
        if ((op.tipo === 'ingrediente' || op.tipo === 'alimento') && op.gramos) {
             name += ` (${op.gramos} gr)`;
        }

        return [
          String(i + 1),
          op.tipo || "-",
          name,
          `Kcal: ${fmt(op.macros?.kcal ?? 0, 0)}\nP: ${fmt(op.macros?.p ?? 0, 1)} g · C: ${fmt(op.macros?.c ?? 0, 1)} g · G: ${fmt(op.macros?.g ?? 0, 1)} g`,
          ingredientesText,
        ];
      });

      autoTable(doc, {
        startY: y + 6,
        margin: { left: M, right: M, top: 60 },
        styles: {
          fontSize: 9,
          cellPadding: 4,
          lineColor: gridLine,
          lineWidth: 0.5,
          textColor: textMain,
          overflow: "linebreak",
          minCellHeight: 14,
        },
        head: [["#", "Tipo", "Nombre", "Métricas", "Ingredientes"]],
        theme: "striped",
        headStyles: {
          fillColor: headFill,
          textColor: [0, 0, 0],
          fontStyle: "bold",
        },
        bodyStyles: { fillColor: [255, 255, 255] },
        columnStyles: {
          0: { cellWidth: 22, halign: "center" },
          1: { cellWidth: 64 },
          2: { cellWidth: 210 },
          3: { cellWidth: 110, halign: "left", fontSize: 8.5 },
          4: { cellWidth: "auto", fontSize: 9 },
        },
        body: rows,
      });

      y = doc.lastAutoTable.finalY + 16;
    });

    doc.save(`dieta_${new Date().toISOString().slice(0, 10)}.pdf`);
  };

  const handleCreateRevisionQuick = async () => {
    try {
      const nueva = await createRevision(id, {}, "Snapshot manual");
      await fetchDieta(nueva._id);
    } catch (err) {
      console.error("Error al crear revisión", err);
    }
  };

  const handleVersionRestored = async (restored) => {
    await fetchDieta(restored._id);
  };

  const handleVersionCreated = async (created) => {
    await fetchDieta(created._id);
  };

  if (!dieta) return <Typography sx={{ p: 4 }}>Cargando dieta...</Typography>;

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
          <Box>
            <Typography variant="h4" fontWeight={800}>
              Detalle de la Dieta
            </Typography>
            <Stack direction="row" spacing={2} mt={1} alignItems="center">
              <Stack direction="row" spacing={0.5} alignItems="center">
                <CalendarMonthIcon fontSize="small" />
                <Typography variant="body2" color="text.secondary">
                  {fechaCreacion}
                </Typography>
              </Stack>
              <Stack direction="row" spacing={0.5} alignItems="center">
                <LocalFireDepartmentIcon fontSize="small" color="error" />
                <Typography variant="body2" color="text.secondary">
                  {fmt(dieta.macros?.kcal || 0, 0)} kcal objetivo
                </Typography>
              </Stack>
            </Stack>
          </Box>

          <Stack
            direction={{ xs: "column", sm: "row" }}
            spacing={1.25}
            useFlexGap
            flexWrap="wrap"
            alignItems={{ xs: "stretch", sm: "center" }}
            sx={{
              minWidth: 0,
              "& > *": { flex: { xs: "1 1 auto", sm: "0 0 auto" } },
            }}
          >
            <Tooltip title="Exportar a PDF">
              <Button
                startIcon={<PictureAsPdfIcon />}
                variant="contained"
                onClick={handleExportPDF}
                fullWidth={isXs}
                size={isXs ? "medium" : "small"}
                sx={{
                  textTransform: "none",
                  borderRadius: 2,
                }}
              >
                Exportar
              </Button>
            </Tooltip>

            <Tooltip title="Guardar versión actual">
              <Button
                startIcon={<SaveAsIcon />}
                variant="outlined"
                onClick={handleCreateRevisionQuick}
                fullWidth={isXs}
                size={isXs ? "medium" : "small"}
                sx={{ textTransform: "none", borderRadius: 2 }}
              >
                Guardar versión
              </Button>
            </Tooltip>

            <Tooltip title="Historial de versiones">
              <Button
                startIcon={<HistoryIcon />}
                variant="outlined"
                onClick={() => setOpenRevisions(true)}
                fullWidth={isXs}
                size={isXs ? "medium" : "small"}
                sx={{ textTransform: "none", borderRadius: 2 }}
              >
                Historial
              </Button>
            </Tooltip>

            <Tooltip title="Editar dieta">
              <Button
                startIcon={<EditIcon />}
                variant="outlined"
                onClick={() => navigate(`/dieta/editar/${id}`)}
                fullWidth={isXs}
                size={isXs ? "medium" : "small"}
                sx={{ textTransform: "none", borderRadius: 2 }}
              >
                Editar
              </Button>
            </Tooltip>

            <Tooltip title="Eliminar dieta">
              <Button
                startIcon={<DeleteOutlineIcon />}
                variant="outlined"
                color="error"
                onClick={() => setConfirmOpen(true)}
                fullWidth={isXs}
                size={isXs ? "medium" : "small"}
                sx={{ textTransform: "none", borderRadius: 2 }}
              >
                Eliminar
              </Button>
            </Tooltip>
          </Stack>
        </Stack>
      </Paper>

      {/* INFO + STATS */}
      <Grid container spacing={3}>
        <Grid item xs={12} md={5}>
          <Paper
            elevation={0}
            sx={{
              p: 3,
              borderRadius: 3,
              border: "1px solid",
              borderColor: "divider",
            }}
          >
            <Typography variant="h6" fontWeight={700} gutterBottom>
              Información general
            </Typography>
            <Divider sx={{ mb: 2 }} />
            <Stack spacing={1}>
              <Typography>
                <strong>Fecha de creación:</strong> {fechaCreacion}
              </Typography>
              <Typography>
                <strong>Calorías totales:</strong>{" "}
                {fmt(dieta.macros?.kcal || 0, 0)} kcal
              </Typography>
              <Typography>
                <strong>Objetivo:</strong> {dieta.objetivo || "-"}
              </Typography>
              <Typography>
                <strong>Estado:</strong> {dieta.estado || "-"}
              </Typography>
            </Stack>
          </Paper>
        </Grid>

        <Grid item xs={12} md={7}>
          <Grid container spacing={2}>
            <Grid item xs={12} sm={6} md={6}>
              <Card
                elevation={0}
                sx={{
                  borderRadius: 3,
                  border: "1px solid",
                  borderColor: "divider",
                  height: "100%",
                }}
              >
                <CardContent>
                  <Stack
                    direction="row"
                    alignItems="center"
                    spacing={1}
                    mb={0.5}
                  >
                    <LocalFireDepartmentIcon color="error" />
                    <Typography variant="overline" color="text.secondary">
                      Calorías objetivo
                    </Typography>
                  </Stack>
                  <Typography variant="h4" fontWeight={800}>
                    {fmt(dieta.macros?.kcal || 0, 0)}{" "}
                    <Typography component="span">kcal</Typography>
                  </Typography>
                </CardContent>
              </Card>
            </Grid>
            <Grid item xs={12} sm={6} md={6}>
              <Card
                elevation={0}
                sx={{
                  borderRadius: 3,
                  border: "1px solid",
                  borderColor: "divider",
                  height: "100%",
                }}
              >
                <CardContent>
                  <Typography variant="overline" color="text.secondary">
                    Reparto de macros (g)
                  </Typography>
                  <Stack spacing={1.2} mt={1.2}>
                    <Stack direction="row" spacing={1} alignItems="center">
                      <EggAltIcon fontSize="small" />
                      <Typography variant="body2">
                        Proteínas:{" "}
                        <strong>{fmt(dieta.macros?.p || 0, 0)} g</strong>
                      </Typography>
                    </Stack>
                    <Stack direction="row" spacing={1} alignItems="center">
                      <BakeryDiningIcon fontSize="small" />
                      <Typography variant="body2">
                        Carbohidratos:{" "}
                        <strong>{fmt(dieta.macros?.c || 0, 0)} g</strong>
                      </Typography>
                    </Stack>
                    <Stack direction="row" spacing={1} alignItems="center">
                      <OpacityIcon fontSize="small" />
                      <Typography variant="body2">
                        Grasas: <strong>{fmt(dieta.macros?.g || 0, 0)} g</strong>
                      </Typography>
                    </Stack>
                  </Stack>

                  {macrosKcal?.total ? (
                    <Typography
                      variant="caption"
                      color="text.secondary"
                      sx={{ display: "block", mt: 1.5 }}
                    >
                      Equivalencia en kcal · P: {fmt(macrosKcal.p, 0)} · C:{" "}
                      {fmt(macrosKcal.c, 0)} · G: {fmt(macrosKcal.g, 0)}
                    </Typography>
                  ) : null}
                </CardContent>
              </Card>
            </Grid>
          </Grid>
        </Grid>
      </Grid>

      {/* COMIDAS */}
      <Paper
        elevation={0}
        sx={{
          p: { xs: 2, md: 3 },
          mt: 3,
          borderRadius: 3,
          border: "1px solid",
          borderColor: "divider",
        }}
      >
        <Typography variant="h6" fontWeight={700} gutterBottom>
          Comidas
        </Typography>
        <Divider sx={{ mb: 2 }} />

        {dieta.comidas?.length > 0 ? (
          <ComidasDieta comidas={dieta.comidas} />
        ) : (
          <Typography color="text.secondary">Sin comidas aún.</Typography>
        )}
      </Paper>

      {/* DIALOGO CONFIRMACION ELIMINAR */}
      <Dialog open={confirmOpen} onClose={() => setConfirmOpen(false)}>
        <DialogTitle>Eliminar dieta</DialogTitle>
        <DialogContent>
          <DialogContentText>
            Esta acción no se puede deshacer. ¿Seguro que quieres eliminar esta
            dieta?
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setConfirmOpen(false)}>Cancelar</Button>
          <Button
            color="error"
            variant="contained"
            onClick={async () => {
              await handleEliminar();
              setConfirmOpen(false);
            }}
          >
            Eliminar
          </Button>
        </DialogActions>
      </Dialog>

      {/* DIALOGO DE HISTORIAL */}
      <RevisionsDialog
        open={openRevisions}
        onClose={() => setOpenRevisions(false)}
        dietaId={id}
        onRestored={handleVersionRestored}
        onCreated={handleVersionCreated}
      />
    </Box>
  );
};

export default VistaDieta;
