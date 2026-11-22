classdef SIGE_HMI < matlab.apps.AppBase
% =====================================================================
%  RETO 4 - HMI DEL SISTEMA SIGE (MATLAB)
%  Curso: Software para Ingenieria (203036) - UNAD
%  Estudiante: Brayan Mauricio Estevez Sierra
%  Uso: escribir  SIGE_HMI  en la consola de MATLAB.
%  Cada iteracion de la simulacion equivale a 1 hora de operacion.
%  Logica de control: reglas del Reto 3 (SOC inicial 50 %, bateria 100 kWh,
%  umbrales 40 % y 20 %, limites 0 % y 100 %).
% =====================================================================

    % ---------------------------------------------------------------
    % COMPONENTES DE LA INTERFAZ
    % ---------------------------------------------------------------
    properties (Access = public)
        UIFigure         matlab.ui.Figure
        PanelEntradas    matlab.ui.container.Panel
        SolarLabel       matlab.ui.control.Label
        SolarSlider      matlab.ui.control.Slider
        EolicaLabel      matlab.ui.control.Label
        EolicaSlider     matlab.ui.control.Slider
        DemandaLabel     matlab.ui.control.Label
        DemandaSlider    matlab.ui.control.Slider
        PanelProc        matlab.ui.container.Panel
        SimLabel         matlab.ui.control.Label
        SimulacionSwitch matlab.ui.control.Switch
        ReiniciarButton  matlab.ui.control.Button
        PanelEstado      matlab.ui.container.Panel
        HoraLabel        matlab.ui.control.Label
        SOCLabel         matlab.ui.control.Label
        RutaLabel        matlab.ui.control.Label
        GaugeLabel       matlab.ui.control.Label
        SOCGauge         matlab.ui.control.Gauge
        PanelReles       matlab.ui.container.Panel
        EscuelaLamp      matlab.ui.control.Lamp
        EscuelaLabel     matlab.ui.control.Label
        BombeoLamp       matlab.ui.control.Lamp
        BombeoLabel      matlab.ui.control.Label
        AlumbradoLamp    matlab.ui.control.Lamp
        AlumbradoLabel   matlab.ui.control.Label
        UIAxes           matlab.ui.control.UIAxes
    end

    % ---------------------------------------------------------------
    % VARIABLES INTERNAS DE LA SIMULACION
    % ---------------------------------------------------------------
    properties (Access = private)
        SOC       = 50      % Estado de carga actual de la bateria [%]
        CapBat    = 100     % Capacidad total de la bateria [kWh]
        Hora      = 0       % Contador de horas simuladas
        tHist     = []      % Buffer de graficacion: tiempo [h]
        GenHist   = []      % Buffer de graficacion: generacion total [kW]
        DemHist   = []      % Buffer de graficacion: demanda [kW]
        BufferMax = 24      % Numero maximo de muestras graficadas
        PausaS    = 0.8     % Pausa entre iteraciones [s]
    end

    % ===============================================================
    % >>>>>>>>>>  CODIGO PARA COPIAR EN APP DESIGNER (.mlapp)  <<<<<<<<<<
    %  Desde aqui hasta la marca "FIN DEL CODIGO PARA APP DESIGNER".
    % ===============================================================
    methods (Access = private)

        % --- Actualiza las etiquetas con el valor de cada consigna ---
        function actualizarEtiquetas(app)
            app.SolarLabel.Text   = sprintf('Generacion solar: %.0f kW', app.SolarSlider.Value);
            app.EolicaLabel.Text  = sprintf('Generacion eolica: %.0f kW', app.EolicaSlider.Value);
            app.DemandaLabel.Text = sprintf('Demanda de la comunidad: %.0f kW', app.DemandaSlider.Value);
        end

        % --- Devuelve el color del LED segun el estado del rele ---
        function c = colorRele(~, activo)
            if activo
                c = [0 0.8 0];          % Verde: rele cerrado (servicio activo)
            else
                c = [1 0 0];            % Rojo: rele abierto (servicio suspendido)
            end
        end

        % --- Devuelve el texto del estado del servicio ---
        function t = textoEstado(~, activo)
            if activo
                t = 'ACTIVO';
            else
                t = 'SUSPENDIDO';
            end
        end

        % --- Muestra el estado de los tres reles en pantalla ---
        function mostrarReles(app, esc, bom, alu)
            app.EscuelaLamp.Color   = colorRele(app, esc);
            app.BombeoLamp.Color    = colorRele(app, bom);
            app.AlumbradoLamp.Color = colorRele(app, alu);
            app.EscuelaLabel.Text   = ['Escuela Rural: ' textoEstado(app, esc)];
            app.BombeoLabel.Text    = ['Bombeo de Agua: ' textoEstado(app, bom)];
            app.AlumbradoLabel.Text = ['Alumbrado Publico: ' textoEstado(app, alu)];
        end

        % --- Configura titulo, ejes y cuadricula del grafico ---
        function configurarEje(app)
            title(app.UIAxes, 'Generacion total vs. demanda');
            xlabel(app.UIAxes, 'Tiempo [h]');
            ylabel(app.UIAxes, 'Potencia [kW]');
            grid(app.UIAxes, 'on');
        end

        % --- Restablece las condiciones iniciales ---
        function reiniciarEstado(app)
            app.SOC = 50;
            app.Hora = 0;
            app.tHist = [];
            app.GenHist = [];
            app.DemHist = [];
            app.SOCGauge.Value = 50;
            app.SOCLabel.Text = 'SOC: 50.0 %';
            app.HoraLabel.Text = 'Hora simulada: 0';
            app.RutaLabel.Text = 'Sistema en espera';
            mostrarReles(app, true, true, true);
            cla(app.UIAxes);
            configurarEje(app);
            actualizarEtiquetas(app);
        end

        % --- Ejecuta UNA iteracion (1 hora) de la logica SIGE ---
        function paso(app)
            Egen = app.SolarSlider.Value + app.EolicaSlider.Value;  % Generacion total [kW]
            Edem = app.DemandaSlider.Value;                         % Demanda [kW]

            if Egen >= Edem
                % ----- Superavit: el excedente carga la bateria -----
                excedente = Egen - Edem;
                app.SOC = min(app.SOC + (excedente / app.CapBat) * 100, 100);
                esc = true; bom = true; alu = true;
                ruta = 'SUPERAVIT: servicios nominales';
            else
                % ----- Deficit: el faltante se extrae de la bateria -----
                faltante = Edem - Egen;
                app.SOC = max(app.SOC - (faltante / app.CapBat) * 100, 0);
                % ----- Desconexion de cargas por prioridad -----
                if app.SOC > 40
                    esc = true; bom = true; alu = true;
                    ruta = 'DEFICIT: Ruta Segura';
                elseif app.SOC > 20
                    esc = true; bom = true; alu = false;
                    ruta = 'DEFICIT: Ruta de Alerta (Alumbrado OFF)';
                else
                    esc = true; bom = false; alu = false;
                    ruta = 'DEFICIT: Ruta de Emergencia (solo Escuela)';
                end
            end

            % ----- Actualizacion de indicadores -----
            app.Hora = app.Hora + 1;
            app.SOCGauge.Value = app.SOC;
            app.SOCLabel.Text  = sprintf('SOC: %.1f %%', app.SOC);
            app.HoraLabel.Text = sprintf('Hora simulada: %d', app.Hora);
            app.RutaLabel.Text = ruta;
            mostrarReles(app, esc, bom, alu);

            % ----- Buffer de graficacion (ultimas 24 muestras) -----
            app.tHist(end+1)   = app.Hora;
            app.GenHist(end+1) = Egen;
            app.DemHist(end+1) = Edem;
            if numel(app.tHist) > app.BufferMax
                app.tHist   = app.tHist(end-app.BufferMax+1:end);
                app.GenHist = app.GenHist(end-app.BufferMax+1:end);
                app.DemHist = app.DemHist(end-app.BufferMax+1:end);
            end
            cla(app.UIAxes);
            plot(app.UIAxes, app.tHist, app.GenHist, '-o', 'LineWidth', 1.8, 'Color', [0 0.6 0.2]);
            hold(app.UIAxes, 'on');
            plot(app.UIAxes, app.tHist, app.DemHist, '-s', 'LineWidth', 1.8, 'Color', [0.85 0.1 0.1]);
            hold(app.UIAxes, 'off');
            xmin = app.tHist(1);
            xmax = max(app.tHist(end), xmin + 1);
            xlim(app.UIAxes, [xmin xmax]);
            ylim(app.UIAxes, [0 max(10, 1.1 * max([app.GenHist app.DemHist]))]);
            configurarEje(app);
            legend(app.UIAxes, {'Generacion total', 'Demanda'}, 'Location', 'northwest');
            drawnow;
        end
    end

    methods (Access = private)

        % --- startupFcn: se ejecuta al abrir la aplicacion ---
        function startupFcn(app)
            reiniciarEstado(app);
        end

        % --- Callback comun de los tres deslizadores (ValueChangedFcn) ---
        function SliderValueChanged(app, event)
            % Se redondea cada consigna a kW enteros para que los valores sean exactos
            app.SolarSlider.Value   = round(app.SolarSlider.Value);
            app.EolicaSlider.Value  = round(app.EolicaSlider.Value);
            app.DemandaSlider.Value = round(app.DemandaSlider.Value);
            actualizarEtiquetas(app);
        end

        % --- Callback del conmutador de simulacion (ValueChangedFcn) ---
        function SimulacionSwitchValueChanged(app, event)
            if strcmp(app.SimulacionSwitch.Value, 'En marcha')
                while isvalid(app) && strcmp(app.SimulacionSwitch.Value, 'En marcha')
                    paso(app);
                    pause(app.PausaS);
                end
            end
        end

        % --- Callback del boton Reiniciar (ButtonPushedFcn) ---
        function ReiniciarButtonPushed(app, event)
            app.SimulacionSwitch.Value = 'Detenido';
            reiniciarEstado(app);
        end
    end
    % ===============================================================
    % >>>>>>>>>>>>>>>  FIN DEL CODIGO PARA APP DESIGNER  <<<<<<<<<<<<<<<<
    % ===============================================================

    % ---------------------------------------------------------------
    % CREACION DE COMPONENTES (solo version programatica)
    % En App Designer estos componentes se crean arrastrandolos.
    % ---------------------------------------------------------------
    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 980 640];
            app.UIFigure.Name = 'SIGE - HMI de supervision de la micro-red';

            % ---- Panel de entradas ----
            app.PanelEntradas = uipanel(app.UIFigure);
            app.PanelEntradas.Title = 'Entradas (consignas de simulacion)';
            app.PanelEntradas.Position = [20 340 310 280];

            app.SolarLabel = uilabel(app.PanelEntradas);
            app.SolarLabel.Position = [20 220 270 22];
            app.SolarSlider = uislider(app.PanelEntradas);
            app.SolarSlider.Limits = [0 150];
            app.SolarSlider.MajorTicks = [0 50 100 150];
            app.SolarSlider.MinorTicks = [];
            app.SolarSlider.Position = [25 205 255 3];
            app.SolarSlider.ValueChangedFcn = createCallbackFcn(app, @SliderValueChanged, true);

            app.EolicaLabel = uilabel(app.PanelEntradas);
            app.EolicaLabel.Position = [20 150 270 22];
            app.EolicaSlider = uislider(app.PanelEntradas);
            app.EolicaSlider.Limits = [0 100];
            app.EolicaSlider.MajorTicks = [0 25 50 75 100];
            app.EolicaSlider.MinorTicks = [];
            app.EolicaSlider.Position = [25 135 255 3];
            app.EolicaSlider.ValueChangedFcn = createCallbackFcn(app, @SliderValueChanged, true);

            app.DemandaLabel = uilabel(app.PanelEntradas);
            app.DemandaLabel.Position = [20 80 270 22];
            app.DemandaSlider = uislider(app.PanelEntradas);
            app.DemandaSlider.Limits = [0 200];
            app.DemandaSlider.MajorTicks = [0 50 100 150 200];
            app.DemandaSlider.MinorTicks = [];
            app.DemandaSlider.Position = [25 65 255 3];
            app.DemandaSlider.ValueChangedFcn = createCallbackFcn(app, @SliderValueChanged, true);

            % ---- Panel de procesamiento ----
            app.PanelProc = uipanel(app.UIFigure);
            app.PanelProc.Title = 'Procesamiento (logica SIGE)';
            app.PanelProc.Position = [20 190 310 135];

            app.SimLabel = uilabel(app.PanelProc);
            app.SimLabel.Text = 'Simulacion:';
            app.SimLabel.Position = [15 85 150 22];
            app.SimulacionSwitch = uiswitch(app.PanelProc, 'slider');
            app.SimulacionSwitch.Items = {'Detenido', 'En marcha'};
            app.SimulacionSwitch.Value = 'Detenido';
            app.SimulacionSwitch.Position = [135 50 60 26];
            app.SimulacionSwitch.ValueChangedFcn = createCallbackFcn(app, @SimulacionSwitchValueChanged, true);

            app.ReiniciarButton = uibutton(app.PanelProc, 'push');
            app.ReiniciarButton.Text = 'Reiniciar';
            app.ReiniciarButton.Position = [100 8 110 28];
            app.ReiniciarButton.ButtonPushedFcn = createCallbackFcn(app, @ReiniciarButtonPushed, true);

            % ---- Panel de estado ----
            app.PanelEstado = uipanel(app.UIFigure);
            app.PanelEstado.Title = 'Estado del sistema';
            app.PanelEstado.Position = [20 20 310 155];

            app.HoraLabel = uilabel(app.PanelEstado);
            app.HoraLabel.Position = [15 105 280 22];
            app.SOCLabel = uilabel(app.PanelEstado);
            app.SOCLabel.FontWeight = 'bold';
            app.SOCLabel.Position = [15 75 280 22];
            app.RutaLabel = uilabel(app.PanelEstado);
            app.RutaLabel.WordWrap = 'on';
            app.RutaLabel.VerticalAlignment = 'top';
            app.RutaLabel.Position = [15 10 280 55];

            % ---- Medidor del SOC ----
            app.GaugeLabel = uilabel(app.UIFigure);
            app.GaugeLabel.Text = 'SOC de la bateria [%]';
            app.GaugeLabel.FontWeight = 'bold';
            app.GaugeLabel.Position = [390 600 160 22];
            app.SOCGauge = uigauge(app.UIFigure, 'circular');
            app.SOCGauge.Limits = [0 100];
            app.SOCGauge.MajorTicks = [0 20 40 60 80 100];
            app.SOCGauge.ScaleColors = {'red', 'yellow', 'green'};
            app.SOCGauge.ScaleColorLimits = [0 20; 20 40; 40 100];
            app.SOCGauge.Position = [370 445 150 150];

            % ---- Panel de reles (LED) ----
            app.PanelReles = uipanel(app.UIFigure);
            app.PanelReles.Title = 'Reles de las cargas (indicadores LED)';
            app.PanelReles.Position = [560 440 390 180];

            app.EscuelaLamp = uilamp(app.PanelReles);
            app.EscuelaLamp.Position = [25 115 24 24];
            app.EscuelaLabel = uilabel(app.PanelReles);
            app.EscuelaLabel.Position = [65 115 300 24];
            app.BombeoLamp = uilamp(app.PanelReles);
            app.BombeoLamp.Position = [25 70 24 24];
            app.BombeoLabel = uilabel(app.PanelReles);
            app.BombeoLabel.Position = [65 70 300 24];
            app.AlumbradoLamp = uilamp(app.PanelReles);
            app.AlumbradoLamp.Position = [25 25 24 24];
            app.AlumbradoLabel = uilabel(app.PanelReles);
            app.AlumbradoLabel.Position = [65 25 300 24];

            % ---- Grafico de potencia ----
            app.UIAxes = uiaxes(app.UIFigure);
            app.UIAxes.Position = [345 20 620 400];

            app.UIFigure.Visible = 'on';
        end
    end

    % ---------------------------------------------------------------
    % CONSTRUCTOR Y DESTRUCTOR DE LA APLICACION
    % ---------------------------------------------------------------
    methods (Access = public)
        function app = SIGE_HMI
            createComponents(app)
            registerApp(app, app.UIFigure)
            runStartupFcn(app, @startupFcn)
            if nargout == 0
                clear app
            end
        end

        function delete(app)
            delete(app.UIFigure)
        end
    end
end
