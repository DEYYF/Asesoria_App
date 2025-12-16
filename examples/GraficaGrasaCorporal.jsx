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

const GraficaGrasaCorporal = ({ historialProgreso }) => {
  const datosFiltrados = historialProgreso
    .filter((h) => h.grasaCorporal)
    .sort((a, b) => new Date(a.fecha) - new Date(b.fecha));

  const data = {
    labels: datosFiltrados.map((h) =>
      new Date(h.fecha).toLocaleDateString()
    ),
    datasets: [
      {
        label: "Grasa Corporal (%)",
        data: datosFiltrados.map((h) => h.grasaCorporal),
        borderColor: "#e91e63",
        backgroundColor: "#e91e6380",
        fill: false,
        tension: 0.3,
      },
    ],
  };

  const options = {
    responsive: true,
    plugins: {
      legend: { display: true },
      title: { display: true, text: "Evolución de Grasa Corporal" },
    },
  };

  return (
    <Paper sx={{ p: 2, mt: 2 }}>
      <Typography variant="subtitle1" mb={1}>
        Gráfica de Grasa Corporal
      </Typography>
      <Box height={300}>
        <Line data={data} options={options} />
      </Box>
    </Paper>
  );
};

export default GraficaGrasaCorporal;
