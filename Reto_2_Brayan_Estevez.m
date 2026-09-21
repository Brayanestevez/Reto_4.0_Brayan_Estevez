%% SIGE - Sistema Inteligente de Gestión Energética
% Reto 2: Modelado del balance híbrido (solar + eólica vs. demanda)
% Curso: Software para Ingeniería (203036) - UNAD
% Autor: Brayan Mauricio Estevez Sierra
% Descripción: simula un ciclo de 24 h de generación solar, generación
% eólica y demanda de la comunidad, y grafica el balance de potencia.

clc;                                                     % Limpia la ventana de comandos
clear;                                                   % Borra las variables del espacio de trabajo
close all;                                               % Cierra todas las figuras abiertas

%% 1. PARÁMETROS DE DISEÑO
P_max_solar   = 25;                                      % Potencia pico de los paneles solares [kW]
P_max_eolica  = 15;                                      % Potencia nominal máxima de los aerogeneradores [kW]
P_max_demanda = 15;                                      % Potencia máxima de diseño de la demanda [kW]
horas = 1:24;                                            % Vector fila de 24 elementos: cada posición es una hora del día

%% 2. (a) GENERACIÓN SOLAR
P_solar = zeros(1, 24);                                  % Inicializa el vector solar en 0 kW (condición de noche)
horas_dia = 6:18;                                        % Horas con radiación solar (las horas 1-5 y 19-24 quedan en 0)
P_solar(horas_dia) = P_max_solar * sin(pi*(horas_dia - 5)/14); % Semicurva sinusoidal: asciende hasta el pico en la hora 12 (25 kW) y desciende después
P_solar = round(P_solar, 2);                             % Redondea a 2 decimales para una lectura limpia de los valores

%% 3. (b) GENERACIÓN EÓLICA
P_eolica = [6.2 7.8 9.1 8.4 10.3 11.9 ...                % Horas 1-6: potencia de los aerogeneradores [kW], variación irregular por el viento
            9.6 7.2 5.8 6.9 8.8 10.7 ...                 % Horas 7-12: el viento sube y baja sin patrón fijo
            12.4 13.6 11.2 9.3 8.1 10.5 ...              % Horas 13-18: continúa la fluctuación del recurso eólico
            12.8 14.2 11.6 9.4 7.7 6.5];                 % Horas 19-24: valores siempre menores o iguales a 15 kW
P_eolica = min(P_eolica, P_max_eolica);                  % Limita cada valor a la potencia nominal para que nunca se supere 15 kW

%% 4. (c) GENERACIÓN HÍBRIDA TOTAL
P_total = P_solar + P_eolica;                            % Suma elemento a elemento los vectores solar y eólico

%% 5. (d) DEMANDA DE LA COMUNIDAD
P_demanda = zeros(1, 24);                                % Inicializa el vector de demanda en 0 kW
P_demanda([1:5, 22:24]) = [3.0 2.5 2.2 2.4 3.1 ...       % Horas 1-5: consumo mínimo nocturno entre 2 kW y 4 kW
                           4.0 3.4 2.8];                 % Horas 22-24: consumo mínimo nocturno entre 2 kW y 4 kW
P_demanda(6:17) = [6.5 7.5 8.5 9.0 9.5 9.8 ...           % Horas 6-11: consumo diurno (escuela y bombeo agrícola) entre 6 kW y 10 kW
                   10.0 9.6 9.2 8.6 8.0 7.5];            % Horas 12-17: consumo diurno entre 6 kW y 10 kW
P_demanda(18:21) = [14.0 15.0 15.0 14.0];                % Horas 18-21: pico de demanda (alumbrado público y retorno doméstico), máximo de 15 kW

%% 6. VALIDACIÓN DE RESTRICCIONES DEL ENUNCIADO
assert(max(P_solar) == P_max_solar, 'El pico solar no es 25 kW');            % Verifica que el pico solar sea 25 kW
assert(P_solar(12) == P_max_solar, 'El pico solar no ocurre en la hora 12'); % Verifica que el pico solar ocurra a mediodía (hora 12)
assert(all(P_solar([1:5, 19:24]) == 0), 'La solar debe ser 0 en la noche');  % Verifica producción nula en las horas 1-5 y 19-24
assert(all(P_eolica <= P_max_eolica), 'La eólica supera 15 kW');             % Verifica que la eólica no supere su potencia nominal
assert(max(P_demanda) == P_max_demanda, 'El pico de demanda no es 15 kW');   % Verifica que la demanda máxima sea 15 kW

%% 7. BALANCE ENERGÉTICO (cálculos de apoyo para el análisis)
balance = P_total - P_demanda;                           % Balance horario [kW]: positivo = excedente, negativo = déficit
horas_superavit = horas(balance > 0);                    % Horas en las que la generación supera a la demanda
horas_deficit   = horas(balance < 0);                    % Horas en las que la demanda supera a la generación (requieren baterías)
E_superavit = sum(balance(balance > 0));                 % Energía excedente del día [kWh] (paso de 1 hora)
E_deficit   = -sum(balance(balance < 0));                % Energía deficitaria del día [kWh] (paso de 1 hora)
fprintf('Generación solar diaria:   %.2f kWh\n', sum(P_solar));    % Imprime la energía solar total del día
fprintf('Generación eólica diaria:  %.2f kWh\n', sum(P_eolica));   % Imprime la energía eólica total del día
fprintf('Generación total diaria:   %.2f kWh\n', sum(P_total));    % Imprime la energía total generada
fprintf('Demanda diaria:            %.2f kWh\n', sum(P_demanda));  % Imprime la energía total demandada
fprintf('Horas con superávit:       %s\n', mat2str(horas_superavit)); % Imprime las horas con excedente
fprintf('Horas con déficit:         %s\n', mat2str(horas_deficit));   % Imprime las horas con déficit
fprintf('Excedente acumulado:       %.2f kWh\n', E_superavit);        % Imprime la energía excedente acumulada
fprintf('Déficit acumulado:         %.2f kWh\n', E_deficit);          % Imprime la energía deficitaria acumulada

%% 8. (e) VISUALIZACIÓN GRÁFICA
figure('Name', 'Balance híbrido SIGE', 'NumberTitle', 'off'); % Crea una ventana de figura con nombre propio
plot(horas, P_total, 'b-o', 'LineWidth', 2, 'MarkerSize', 5); % Grafica la Generación Total en azul con marcadores circulares
hold on;                                                 % Mantiene la figura para superponer la segunda curva
plot(horas, P_demanda, 'r-s', 'LineWidth', 2, 'MarkerSize', 5); % Grafica la Demanda de la comunidad en rojo con marcadores cuadrados
hold off;                                                % Libera la figura una vez trazadas ambas curvas
title('Balance energético híbrido de la micro-red SIGE (ciclo de 24 horas)'); % Título claro del gráfico
xlabel('Tiempo (horas)');                                % Etiqueta del eje X
ylabel('Potencia (kW)');                                 % Etiqueta del eje Y (kilovatios)
grid on;                                                 % Activa la cuadrícula de fondo
legend('Generación total (solar + eólica)', 'Demanda de la comunidad', 'Location', 'northeast'); % Leyenda que identifica cada curva
xlim([1 24]);                                            % Límites del eje X: de la hora 1 a la hora 24
ylim([0 40]);                                            % Límites del eje Y: de 0 kW a 40 kW
xticks(1:24);                                            % Marca cada hora en el eje X
