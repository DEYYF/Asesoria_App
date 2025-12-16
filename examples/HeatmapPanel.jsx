// src/components/Perfil/HeatmapPanel.jsx
import { useEffect, useState } from "react";
import { Box, Paper, Typography, Stack, Skeleton, Tooltip, Grid } from "@mui/material";
import API from "../../services/api";

// SVG Paths detallados para Frontal y Trasera
// Source based on standard muscle map SVGs
// SVG Paths detallados y refinados
const BODY_PATHS = {
    front: {
        Traps: "M103,18 L115,22 L110,35 L90,35 L85,22 L97,18 Z",
        Pectorals: "M75,45 Q100,55 125,45 Q135,60 125,80 Q100,85 75,80 Q65,60 75,45 Z", // Más ancho y definido
        Deltoids: "M60,40 Q50,55 55,70 L70,60 Z M140,40 Q150,55 145,70 L130,60 Z",
        Biceps: "M55,70 Q50,90 55,100 L68,90 Z M145,70 Q150,90 145,100 L132,90 Z",
        Forearms: "M50,100 Q45,125 50,135 L62,125 Z M150,100 Q155,125 150,135 L138,125 Z",
        Abs: "M85,80 L115,80 L112,115 L88,115 Z",
        Obliques: "M85,80 L72,100 L80,120 L88,115 Z M115,80 L128,100 L120,120 L112,115 Z",
        Quads: "M80,120 Q70,170 80,210 L95,200 L90,125 Z M120,120 Q130,170 120,210 L105,200 L110,125 Z",
        Calves: "M80,210 Q75,235 80,255 L90,245 Z M120,210 Q125,235 120,255 L110,245 Z",
    },
    back: {
        Traps: "M85,20 L115,20 L110,40 L90,40 Z",
        Lats: "M80,40 L65,70 L85,90 L115,90 L135,70 L120,40 L110,40 L90,40 Z", 
        LowerBack: "M90,90 L110,90 L105,110 L95,110 Z",
        Glutes: "M80,110 L120,110 Q130,135 120,150 L80,150 Q70,135 80,110 Z",
        Hamstrings: "M80,150 Q75,185 80,210 L95,205 L90,150 Z M120,150 Q125,185 120,210 L105,205 L110,150 Z",
        Calves: "M80,210 Q75,235 80,255 L90,245 Z M120,210 Q125,235 120,255 L110,245 Z",
        Triceps: "M60,55 Q55,75 60,85 L70,75 Z M140,55 Q145,75 140,85 L130,75 Z",
        RearDelts: "M60,40 L70,55 L60,55 Z M140,40 L130,55 L140,55 Z",
    }
};

// Mapa Grupos Backend -> Array de Partes SVG
const GROUP_MAPPING = {
  "Pecho": ["front.Pectorals"],
  "Espalda": ["back.Lats", "back.LowerBack", "back.RearDelts"], // Trapecio separado ahora
  "Trapecio": ["back.Traps", "front.Traps"],
  "Hombro": ["front.Deltoids", "back.RearDelts"],
  "Brazo": ["front.Biceps", "back.Triceps"],
  "Antebrazo": ["front.Forearms"],
  "Glúteo": ["back.Glutes"],
  "Cuádriceps": ["front.Quads"],
  "Femoral": ["back.Hamstrings"],
  "Pierna": ["front.Quads", "back.Hamstrings", "front.Calves", "back.Calves", "back.Glutes"], // Fallback si usa "Pierna" genérico
  "Gemelo": ["back.Calves", "front.Calves"],
  "CINTURA ANCHA": ["front.Obliques"], 
  "CINTURA ESTRECHA": ["front.Abs"]
};

import { Select, MenuItem, InputLabel, FormControl } from "@mui/material";

function BodyMap({ data }) {
    
    const getColor = (targetPart) => {
        let value = null;
        Object.keys(data).forEach(backendGroup => {
            const affectedParts = GROUP_MAPPING[backendGroup] || []; 
            if (affectedParts.includes(targetPart)) {
                value = data[backendGroup];
            }
        });

        if (!value) return "#cfd8dc"; 
        
        return "#2196f3"; 
    };

    const getValue = (targetPart) => {
         let value = null;
         let label = "";
         Object.keys(data).forEach(backendGroup => {
            const affectedParts = GROUP_MAPPING[backendGroup] || []; 
            if (affectedParts.includes(targetPart)) {
                value = data[backendGroup];
                label = backendGroup;
            }
        });
        return value ? `${label}: ${value} cm` : "";
    }

    return (
        <Stack direction="row" spacing={6} justifyContent="center" height={450} width="100%" alignItems="center">
             {/* VISTA FRONTAL */}
            <Box position="relative" height="100%" width={180}>
                <svg viewBox="0 0 200 320" style={{ height: '100%', width: '100%', filter: 'drop-shadow(0px 4px 4px rgba(0,0,0,0.1))' }}>
                     {/* Silueta Base Frontal Más Definida */}
                    <path d="M100,5 Q125,5 140,25 L160,35 L170,100 L160,140 L140,230 L135,290 L115,310 L100,270 L85,310 L65,290 L60,230 L40,140 L30,100 L40,35 L60,25 Q75,5 100,5 Z" fill="#eceff1" stroke="#b0bec5" strokeWidth="1.5"/>
                    
                    {Object.keys(BODY_PATHS.front).map(part => (
                        <Tooltip key={part} title={getValue(`front.${part}`)} arrow placement="top">
                            <path 
                                d={BODY_PATHS.front[part]} 
                                fill={getColor(`front.${part}`)} 
                                stroke="#fff" 
                                strokeWidth="1.5"
                                style={{ transition: 'all 0.3s ease', cursor: 'pointer', opacity: 0.9 }}
                                onMouseEnter={(e) => e.target.style.opacity = 1}
                                onMouseLeave={(e) => e.target.style.opacity = 0.9}
                            />
                        </Tooltip>
                    ))}
                </svg>
                <Typography variant="overline" display="block" align="center" fontWeight={700} color="text.secondary" sx={{ mt: 1 }}>FRONTAL</Typography>
            </Box>

            {/* VISTA TRASERA */}
            <Box position="relative" height="100%" width={180}>
                 <svg viewBox="0 0 200 320" style={{ height: '100%', width: '100%', filter: 'drop-shadow(0px 4px 4px rgba(0,0,0,0.1))' }}>
                    {/* Silueta Base Trasera Más Definida */}
                    <path d="M100,5 Q125,5 140,25 L160,35 L170,100 L160,140 L140,230 L135,290 L115,310 L100,270 L85,310 L65,290 L60,230 L40,140 L30,100 L40,35 L60,25 Q75,5 100,5 Z" fill="#eceff1" stroke="#b0bec5" strokeWidth="1.5"/>
                    
                    {Object.keys(BODY_PATHS.back).map(part => (
                         <Tooltip key={part} title={getValue(`back.${part}`)} arrow placement="top">
                            <path 
                                d={BODY_PATHS.back[part]} 
                                fill={getColor(`back.${part}`)} 
                                stroke="#fff" 
                                strokeWidth="1.5"
                                style={{ transition: 'all 0.3s ease', cursor: 'pointer', opacity: 0.9 }}
                                onMouseEnter={(e) => e.target.style.opacity = 1}
                                onMouseLeave={(e) => e.target.style.opacity = 0.9}
                            />
                        </Tooltip>
                    ))}
                </svg>
                <Typography variant="overline" display="block" align="center" fontWeight={700} color="text.secondary" sx={{ mt: 1 }}>DORSAL</Typography>
            </Box>
        </Stack>
    );
}

export default function HeatmapPanel({ clienteId }) {
    const [data, setData] = useState(null);
    const [history, setHistory] = useState([]);
    const [selectedId, setSelectedId] = useState("");

    // Cargar historial de fechas
    useEffect(() => {
        if (!clienteId) return;
        API.get(`/entrenamientos/registros/cliente/${clienteId}/fechas-medidas`)
           .then(res => {
               const list = res.data || [];
               setHistory(list);
               if (list.length > 0) setSelectedId(list[0]._id);
           })
           .catch(err => console.error(err));
    }, [clienteId]);

    // Cargar datos cuando cambia la selección
    useEffect(() => {
        if(!clienteId) return;
        
        const q = selectedId ? `?progressId=${selectedId}` : "";
        API.get(`/entrenamientos/registros/cliente/${clienteId}/medidas-heatmap${q}`)
           .then(res => setData(res.data || {}))
           .catch(err => console.error(err));
    }, [clienteId, selectedId]);

    return (
        <Paper sx={{ p: 3, borderRadius: 3, mb: 3 }} variant="outlined">
            <Grid container spacing={4} alignItems="center">
                <Grid item xs={12} md={4}>
                     <Typography variant="h6" fontWeight={700} gutterBottom>Mapa Corporal</Typography>
                     
                     <FormControl fullWidth size="small" sx={{ mb: 2, mt: 1 }}>
                        <InputLabel>Fecha de registro</InputLabel>
                        <Select
                            value={selectedId}
                            label="Fecha de registro"
                            onChange={(e) => setSelectedId(e.target.value)}
                            disabled={history.length === 0}
                        >
                            {history.length === 0 && <MenuItem disabled>No hay registros</MenuItem>}
                            {history.map((h) => (
                                <MenuItem key={h._id} value={h._id}>
                                    {new Date(h.fecha).toLocaleDateString()}
                                </MenuItem>
                            ))}
                        </Select>
                     </FormControl>

                     <Typography variant="body2" color="text.secondary" paragraph>
                        Visualización de las medidas registradas en la fecha seleccionada.
                     </Typography>
                     
                     <Box sx={{ mt: 2 }}>
                        <Stack direction="row" alignItems="center" spacing={1}>
                            <Box width={20} height={20} bgcolor="#eceff1" border="1px solid #b0bec5" />
                            <Typography variant="caption">Sin dato</Typography>
                        </Stack>
                        <Stack direction="row" alignItems="center" spacing={1} mt={0.5}>
                            <Box width={20} height={20} bgcolor="#2196f3" />
                            <Typography variant="caption">Registrado</Typography>
                        </Stack>
                     </Box>
                </Grid>
                <Grid item xs={12} md={8} sx={{ display: 'flex', justifyContent: 'center' }}>
                     {data ? <BodyMap data={data} /> : <Skeleton variant="rectangular" width={200} height={300} rounded />}
                </Grid>
            </Grid>
        </Paper>
    );
}
