// GraficaMuscular.jsx
import { Line } from "react-chartjs-2";
import { Box, Typography, Paper } from "@mui/material";
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
} from "chart.js";

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend
);

const colores = [
  "#3f51b5", "#e91e63", "#4caf50", "#ff9800",
  "#9c27b0", "#2196f3", "#f44336", "#00bcd4",
  "#795548", "#607d8b", "#cddc39", "#ffeb3b",
  "#ff5722", "#673ab7", "#009688", "#3e2723"
];

const GraficaMuscular = ({ historialProgreso }) => {
  const fechas = historialProgreso
    .filter((h) => h.musculo && h.musculo.length)
    .map((h) => new Date(h.fecha).toLocaleDateString());

  // Construimos un mapa con los músculos y sus valores por fecha
  const mapaMusculos = {};
  historialProgreso.forEach((h) => {
    h.musculo?.forEach(({ nombre, medida }) => {
      if (!mapaMusculos[nombre]) {
        mapaMusculos[nombre] = [];
      }
      mapaMusculos[nombre].push(medida);
    });
  });

  const datasets = Object.keys(mapaMusculos).map((musculo, i) => ({
    label: musculo,
    data: mapaMusculos[musculo],
    borderColor: colores[i % colores.length],
    backgroundColor: colores[i % colores.length] + "80",
    fill: false,
    tension: 0.3,
  }));

  const data = {
    labels: fechas,
    datasets,
  };

  const options = {
    responsive: true,
    plugins: {
      legend: { display: true },
      title: { display: true, text: "Evolución de Medidas Musculares" },
    },
  };

  return (
    <Paper sx={{ p: 2, mt: 2 }}>
      <Typography variant="subtitle1" mb={1}>
        Gráfica de Medidas Musculares
      </Typography>
      <Box height={350}>
        <Line data={data} options={options} />
      </Box>
    </Paper>
  );
};

export default GraficaMuscular;
