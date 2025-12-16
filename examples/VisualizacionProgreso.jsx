// src/components/Perfil/VisualizacionProgreso.jsx
import { useEffect, useState, useMemo } from "react";
import {
  Box,
  Typography,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Paper,
  Stack,
  ToggleButton,
  ToggleButtonGroup,
  Grid,
  Card,
  CardContent,
  Tooltip,
} from "@mui/material";
import { Line } from "react-chartjs-2";
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip as ChartTooltip,
  Legend,
} from "chart.js";
import API from "../../services/api";

// Icons
import EmojiEventsIcon from '@mui/icons-material/EmojiEvents';
import ScaleIcon from '@mui/icons-material/Scale';
import FitnessCenterIcon from '@mui/icons-material/FitnessCenter';
import InfoOutlinedIcon from '@mui/icons-material/InfoOutlined';

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  ChartTooltip,
  Legend
);

const fmt = (n) => typeof n === 'number' ? n.toLocaleString() : '-';

export default function VisualizacionProgreso({ clienteId }) {
  const [ejercicios, setEjercicios] = useState([]);
  const [selectedEjercicio, setSelectedEjercicio] = useState("");
  
  const [historyData, setHistoryData] = useState([]); // Raw data
  const [metric, setMetric] = useState("strength"); // strength | volume | reps

  // 1. Cargar lista de ejercicios disponibles
  useEffect(() => {
    if (!clienteId) return;
    API.get(`/entrenamientos/registros/cliente/${clienteId}/ejercicios`)
       .then(res => {
           setEjercicios(res.data || []);
           if (res.data && res.data.length > 0) {
               setSelectedEjercicio(res.data[0]); // Seleccionar el primero
           }
       })
       .catch(err => console.error(err));
  }, [clienteId]);

  // 2. Cargar historial
  useEffect(() => {
      if (!clienteId || !selectedEjercicio) return;
      
      API.get(`/entrenamientos/registros/cliente/${clienteId}/historial`, {
          params: { ejercicio: selectedEjercicio }
      })
      .then(res => {
          setHistoryData(res.data || []);
      })
      .catch(err => console.error(err));
  }, [clienteId, selectedEjercicio]);

  // 3. Calcular Récords (PB)
  const records = useMemo(() => {
      if (!historyData.length) return null;
      
      const maxWeight = Math.max(...historyData.map(d => d.maxWeight || 0));
      const max1RM = Math.max(...historyData.map(d => d.estimated1RM || 0));
      const maxVolume = Math.max(...historyData.map(d => d.totalVolume || 0));

      return { maxWeight, max1RM, maxVolume };
  }, [historyData]);

  // 4. Preparar data para el gráfico según métrica
  const chartData = useMemo(() => {
      if (!historyData.length) return null;

      const labels = historyData.map(d => new Date(d.fecha).toLocaleDateString(undefined, { month: 'short', day: 'numeric' }));
      
      let datasets = [];

      if (metric === 'strength') {
          datasets = [
            {
                label: "Peso Máximo (kg)",
                data: historyData.map(d => d.maxWeight),
                borderColor: "rgb(53, 162, 235)",
                backgroundColor: "rgba(53, 162, 235, 0.5)",
                tension: 0.3
            },
            {
                label: "1RM Estimado (kg)",
                data: historyData.map(d => d.estimated1RM),
                borderColor: "rgb(255, 99, 132)",
                backgroundColor: "rgba(255, 99, 132, 0.5)",
                tension: 0.3,
                borderDash: [5, 5]
            }
          ];
      } else if (metric === 'volume') {
          datasets = [{
              label: "Volumen Total (kg)",
              data: historyData.map(d => d.totalVolume),
              borderColor: "rgb(153, 102, 255)",
              backgroundColor: "rgba(153, 102, 255, 0.5)",
              tension: 0.3,
              fill: true
          }];
      } else if (metric === 'reps') {
          datasets = [{
              label: "Reps Máx (serie)",
              data: historyData.map(d => d.maxReps),
              borderColor: "rgb(75, 192, 192)",
              backgroundColor: "rgba(75, 192, 192, 0.5)",
              tension: 0.1
          }];
      }

      return { labels, datasets };
  }, [historyData, metric]);

  return (
    <Box>
        <Stack direction={{ xs: 'column', sm: 'row' }} justifyContent="space-between" alignItems="center" mb={3} spacing={2}>
            <Typography variant="h6" fontWeight={700}>Evolución</Typography>
            <Box sx={{ minWidth: 200 }}>
                <FormControl fullWidth size="small">
                    <InputLabel>Ejercicio</InputLabel>
                    <Select
                        value={selectedEjercicio}
                        label="Ejercicio"
                        onChange={(e) => setSelectedEjercicio(e.target.value)}
                    >
                        {ejercicios.map((ej) => (
                            <MenuItem key={ej} value={ej}>{ej}</MenuItem>
                        ))}
                    </Select>
                </FormControl>
            </Box>
        </Stack>

        {/* SUMMARY CARDS */}
        {records && (
            <Grid container spacing={2} mb={3}>
                <Grid item xs={12} sm={4}>
                    <Card variant="outlined" sx={{ borderRadius: 3 }}>
                        <CardContent sx={{ pb: '16px!important' }}>
                            <Tooltip title="Peso máximo teórico que podrías levantar a 1 repetición (Estimado Epley)" arrow>
                                <Stack direction="row" spacing={1} alignItems="center" mb={1} sx={{ cursor: 'help', width: 'fit-content' }}>
                                    <EmojiEventsIcon color="warning" />
                                    <Typography variant="caption" color="text.secondary" fontWeight={700}>MEJOR 1RM</Typography>
                                    <InfoOutlinedIcon sx={{ fontSize: 14 }} color="action" />
                                </Stack>
                            </Tooltip>
                            <Typography variant="h5" fontWeight={800}>{fmt(parseInt(records.max1RM))} kg</Typography>
                        </CardContent>
                    </Card>
                </Grid>
                <Grid item xs={12} sm={4}>
                    <Card variant="outlined" sx={{ borderRadius: 3 }}>
                        <CardContent sx={{ pb: '16px!important' }}>
                            <Tooltip title="El mayor peso absoluto que has movido en una serie" arrow>
                                <Stack direction="row" spacing={1} alignItems="center" mb={1} sx={{ cursor: 'help', width: 'fit-content' }}>
                                    <ScaleIcon color="info" />
                                    <Typography variant="caption" color="text.secondary" fontWeight={700}>PESO MÁXIMO</Typography>
                                    <InfoOutlinedIcon sx={{ fontSize: 14 }} color="action" />
                                </Stack>
                            </Tooltip>
                            <Typography variant="h5" fontWeight={800}>{fmt(records.maxWeight)} kg</Typography>
                        </CardContent>
                    </Card>
                </Grid>
                <Grid item xs={12} sm={4}>
                    <Card variant="outlined" sx={{ borderRadius: 3 }}>
                        <CardContent sx={{ pb: '16px!important' }}>
                            <Tooltip title="Carga total (Series × Reps × Peso) movida en una sola sesión" arrow>
                                <Stack direction="row" spacing={1} alignItems="center" mb={1} sx={{ cursor: 'help', width: 'fit-content' }}>
                                    <FitnessCenterIcon color="secondary" />
                                    <Typography variant="caption" color="text.secondary" fontWeight={700}>VOLUMEN RÉCORD</Typography>
                                    <InfoOutlinedIcon sx={{ fontSize: 14 }} color="action" />
                                </Stack>
                            </Tooltip>
                            <Typography variant="h5" fontWeight={800}>{fmt(records.maxVolume)} kg</Typography>
                        </CardContent>
                    </Card>
                </Grid>
            </Grid>
        )}

        {/* CONTROLS & CHART */}
        {chartData ? (
            <Paper elevation={0} sx={{ p: 2, borderRadius: 3, border: "1px solid", borderColor: "divider" }}>
                <Stack direction="row" justifyContent="flex-end" mb={2}>
                    <ToggleButtonGroup
                        size="small"
                        color="primary"
                        value={metric}
                        exclusive
                        onChange={(e, v) => v && setMetric(v)}
                    >
                        <ToggleButton value="strength" sx={{ px: 2, fontWeight: 700 }}>Fuerza</ToggleButton>
                        <ToggleButton value="volume" sx={{ px: 2, fontWeight: 700 }}>Volumen</ToggleButton>
                        <ToggleButton value="reps" sx={{ px: 2, fontWeight: 700 }}>Reps</ToggleButton>
                    </ToggleButtonGroup>
                </Stack>

                <Box height={350}>
                    <Line 
                        data={chartData} 
                        options={{
                            responsive: true,
                            maintainAspectRatio: false,
                            plugins: {
                                legend: { position: 'top' },
                                tooltip: { 
                                    mode: 'index',
                                    intersect: false
                                }
                            },
                            scales: {
                                y: { 
                                    beginAtZero: true, 
                                    grid: { color: "#f0f0f0" }
                                },
                                x: {
                                    grid: { display: false }
                                }
                            }
                        }} 
                    />
                </Box>
            </Paper>
        ) : (
            <Typography color="text.secondary" align="center" py={4}>
                Selecciona un ejercicio con registros para ver su evolución.
            </Typography>
        )}
    </Box>
  );
}
