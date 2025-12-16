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

const GraficaPeso = ({ historialProgreso }) => {
  const datosFiltrados = historialProgreso
    .filter((h) => h.peso)
    .sort((a, b) => new Date(a.fecha) - new Date(b.fecha));

  const data = {
    labels: datosFiltrados.map((h) =>
      new Date(h.fecha).toLocaleDateString()
    ),
    datasets: [
      {
        label: "Peso (kg)",
        data: datosFiltrados.map((h) => h.peso),
        borderColor: "#3f51b5",
        backgroundColor: "#3f51b580",
        fill: false,
        tension: 0.3,
      },
    ],
  };

  const options = {
    responsive: true,
    plugins: {
      legend: { display: true },
      title: { display: true, text: "Evolución del Peso" },
    },
  };

  return (
    <Paper sx={{ p: 2, mt: 2 }}>
      <Typography variant="subtitle1" mb={1}>
        Gráfica de Peso
      </Typography>
      <Box height={300}>
        <Line data={data} options={options} />
      </Box>
    </Paper>
  );
};

export default GraficaPeso;
