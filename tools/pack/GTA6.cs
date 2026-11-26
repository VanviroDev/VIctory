using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

// GTA6.exe - tudo em um so: extrai o runtime (VIctory DexNom RayTime + Agility
// SDK), acha o dump, cria o game-path e joga. Teclado e mouse ja entram como
// controle Xbox; a janela recebe foco sozinha para o titulo sair da tela de
// configuracao.
static class GTA6
{
    const string GameExe = "game_scarlett_master.exe";
    // Tudo mora na pasta do GTA6.exe: runtime, D3D12, cache, state, logs.
    // Mover a pasta inteira nao quebra nada.
    static readonly string Runtime = AppDomain.CurrentDomain.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar);
    static readonly string GamePathFile = Path.Combine(Runtime, "game-path.txt");

    static Form window;
    static Label status;
    static Button play1080;
    static Button play1440;
    static Process running;
    static Timer focus;
    static int focusTicks;

    [STAThread]
    static void Main(string[] args)
    {
        bool headless = args.Length > 0 && args[0].StartsWith("--play", StringComparison.Ordinal);
        bool installOnly = args.Length > 0 && args[0] == "--install";

        try
        {
            Install();
        }
        catch (Exception error)
        {
            if (headless || installOnly)
            {
                Environment.Exit(1);
                return;
            }
            MessageBox.Show("Falha ao preparar o runtime.\n\n" + error.Message, "GTA6",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }

        if (installOnly)
        {
            Environment.Exit(0);
            return;
        }

        if (headless)
        {
            try
            {
                Process game = StartGame(args[0] == "--play-1440p", true);
                game.WaitForExit();
                Environment.Exit(game.ExitCode);
            }
            catch (Exception error)
            {
                MessageBox.Show(error.Message, "GTA6", MessageBoxButtons.OK, MessageBoxIcon.Error);
                Environment.Exit(1);
            }
            return;
        }

        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        BuildWindow();
        Application.Run(window);
    }

    // ---------------------------------------------------------------- install

    static void Install()
    {
        Directory.CreateDirectory(Runtime);
        Directory.CreateDirectory(Path.Combine(Runtime, "D3D12"));

        Extract("victory.exe", Path.Combine(Runtime, "victory.exe"));
        Extract("victory-play.exe", Path.Combine(Runtime, "victory-play.exe"));
        Extract("victory-warm.exe", Path.Combine(Runtime, "victory-warm.exe"));
        Extract("D3D12Core.dll", Path.Combine(Runtime, "D3D12", "D3D12Core.dll"));
        Extract("CONTROLES.md", Path.Combine(Runtime, "CONTROLES.md"));
        Extract("BUILD-MAQUINA.md", Path.Combine(Runtime, "BUILD-MAQUINA.md"));
        Extract("OTIMIZACOES.md", Path.Combine(Runtime, "OTIMIZACOES.md"));

        if (!File.Exists(GamePathFile) || !File.Exists(ReadGamePath()))
        {
            string found = FindGame();
            if (found != null)
            {
                WriteGamePath(found);
            }
        }
    }

    static void Extract(string name, string target)
    {
        Assembly assembly = Assembly.GetExecutingAssembly();
        using (Stream source = assembly.GetManifestResourceStream(name))
        {
            if (source == null)
            {
                throw new InvalidOperationException("Pacote incompleto: " + name);
            }
            if (File.Exists(target) && new FileInfo(target).Length == source.Length)
            {
                return;
            }
            string temporary = target + ".new";
            using (FileStream output = new FileStream(temporary, FileMode.Create, FileAccess.Write, FileShare.None))
            {
                source.CopyTo(output);
            }
            if (File.Exists(target))
            {
                File.Delete(target);
            }
            File.Move(temporary, target);
        }
    }

    static string ReadGamePath()
    {
        try
        {
            return File.ReadAllText(GamePathFile).Trim().TrimStart('\uFEFF').Trim();
        }
        catch (Exception)
        {
            return "";
        }
    }

    static void WriteGamePath(string folder)
    {
        File.WriteAllText(GamePathFile, Path.Combine(folder, GameExe), new UTF8Encoding(false));
    }

    static string FindGame()
    {
        string profile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        string[] candidates =
        {
            Path.Combine(profile, "Downloads", "GTA6.Xbox.v1.0.2.1-CYBERLEEK"),
            Path.Combine(profile, "Downloads", "GTA6.Xbox.v1.0.2.1"),
            Path.Combine(profile, "Desktop", "GTA6.Xbox.v1.0.2.1-CYBERLEEK"),
            @"C:\GTA6.Xbox.v1.0.2.1-CYBERLEEK",
            @"D:\GTA6.Xbox.v1.0.2.1",
            @"D:\GTA6.Xbox.v1.0.2.1-CYBERLEEK",
        };
        foreach (string folder in candidates)
        {
            if (File.Exists(Path.Combine(folder, GameExe)))
            {
                return folder;
            }
        }
        return null;
    }

    static bool AskGame()
    {
        using (FolderBrowserDialog dialog = new FolderBrowserDialog())
        {
            dialog.Description = "Escolha a pasta que tem o arquivo " + GameExe + ".";
            dialog.ShowNewFolderButton = false;
            string current = ReadGamePath();
            if (current.Length > 0)
            {
                string folder = Path.GetDirectoryName(current);
                if (Directory.Exists(folder))
                {
                    dialog.SelectedPath = folder;
                }
            }
            if (dialog.ShowDialog(window) != DialogResult.OK)
            {
                return false;
            }
            if (!File.Exists(Path.Combine(dialog.SelectedPath, GameExe)))
            {
                MessageBox.Show("Essa pasta nao tem o " + GameExe + ".", "GTA6",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return false;
            }
            WriteGamePath(dialog.SelectedPath);
            return true;
        }
    }

    // ------------------------------------------------------------------- game

    static Process StartGame(bool high, bool headless)
    {
        string game = ReadGamePath();
        if (game.Length == 0 || !File.Exists(game))
        {
            if (headless || !AskGame())
            {
                throw new FileNotFoundException("Escolha a pasta do jogo no launcher.");
            }
            game = ReadGamePath();
        }

        string exe = Path.Combine(Runtime, "victory-play.exe");
        ProcessStartInfo start = new ProcessStartInfo(exe);
        start.WorkingDirectory = Runtime;
        start.UseShellExecute = false;
        start.Arguments = (high
            ? "--no-rt --console series-x --1080p-to-1440p --local-gpu-memory --sparse-textures --no-upload-ahead"
            : "--no-rt --console series-s --local-gpu-memory --sparse-textures --no-upload-ahead")
            + " \"" + game + "\"";
        start.EnvironmentVariables["VICTORY_AMBIENT_FALLBACK"] = "1";
        start.EnvironmentVariables["VICTORY_FSR_4K"] = "0";
        start.EnvironmentVariables["VICTORY_LOG"] = "warn";
        start.EnvironmentVariables["VICTORY_FILL_WORKERS"] = "6";
        start.EnvironmentVariables["VICTORY_WIDE_WORKERS"] = "6";
        start.EnvironmentVariables["VICTORY_PARALLEL_PRELUDES"] = "1";
        // 8 GB card: the system gives the process about 7.2 GB of its own
        // memory. Past that Windows moves textures to shared memory and the
        // device is removed (the runtime's own note: runs 20 and 24). Cap
        // the title-filled copies at 5.2 GB and leave the rest for render
        // targets, buffers and the swap chain.
        start.EnvironmentVariables["VICTORY_TEXTURE_BUDGET_MB"] = "5200";
        start.EnvironmentVariables["VICTORY_TEXTURE_ROOM_PERCENT"] = "80";
        // The title otherwise believes the television is 4K and renders a 4K
        // scene into a 1080p window. Tell it the window's own size.
        start.EnvironmentVariables["VICTORY_DISPLAY_MODE"] = high ? "2560x1440" : "1920x1080";
        foreach (string name in new[] { "VICTORY_AMBIENT_FALLBACK", "VICTORY_FSR_4K", "VICTORY_LOG", "VICTORY_FILL_WORKERS", "VICTORY_WIDE_WORKERS", "VICTORY_PARALLEL_PRELUDES", "VICTORY_TEXTURE_BUDGET_MB", "VICTORY_TEXTURE_ROOM_PERCENT", "VICTORY_DISPLAY_MODE", "VICTORY_FRAME_INTERVAL" })
        {
            string value = Environment.GetEnvironmentVariable(name);
            if (!string.IsNullOrEmpty(value))
            {
                start.EnvironmentVariables[name] = value;
            }
        }
        return Process.Start(start);
    }

    static void Play(bool high)
    {
        if (running != null && !running.HasExited)
        {
            status.Text = "O jogo ja esta rodando.";
            return;
        }

        try
        {
            running = StartGame(high, false);
        }
        catch (Exception error)
        {
            MessageBox.Show(error.Message, "GTA6", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }

        play1080.Enabled = false;
        play1440.Enabled = false;
        status.Text = high ? "Abrindo em 1440p..." : "Abrindo em 1080p...";

        focusTicks = 0;
        focus.Start();

        running.EnableRaisingEvents = true;
        running.Exited += delegate
        {
            try
            {
                window.BeginInvoke((MethodInvoker)delegate { Finished(); });
            }
            catch (Exception)
            {
            }
        };
    }

    static void Finished()
    {
        focus.Stop();
        int code = -1;
        try
        {
            code = running.ExitCode;
        }
        catch (Exception)
        {
        }
        running = null;
        play1080.Enabled = true;
        play1440.Enabled = true;
        if (code == 0)
        {
            status.Text = "Jogo encerrado. Pronto para abrir de novo.";
            return;
        }
        status.Text = "Runtime terminou com codigo " + code + ". Veja Logs.";
        string tail = LogTail();
        if (tail != null)
        {
            MessageBox.Show("Codigo " + code + ".\n\n" + tail, "GTA6 - ultimas linhas do log",
                MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
    }

    static string LogTail()
    {
        try
        {
            string folder = Path.Combine(Runtime, "logs");
            string[] files = Directory.GetFiles(folder, "*.log");
            if (files.Length == 0)
            {
                return null;
            }
            Array.Sort(files, delegate (string a, string b)
            {
                return File.GetLastWriteTime(b).CompareTo(File.GetLastWriteTime(a));
            });
            string[] lines = File.ReadAllLines(files[0]);
            int from = Math.Max(0, lines.Length - 10);
            string text = string.Join("\n", lines, from, lines.Length - from);
            if (text.Length > 1500)
            {
                text = text.Substring(text.Length - 1500);
            }
            return text;
        }
        catch (Exception)
        {
            return null;
        }
    }

    // -------------------------------------------------------------------- ui

    static void BuildWindow()
    {
        window = new Form();
        window.Text = "GTA6 no PC - tudo em um";
        window.ClientSize = new Size(520, 316);
        window.FormBorderStyle = FormBorderStyle.FixedSingle;
        window.MaximizeBox = false;
        window.StartPosition = FormStartPosition.CenterScreen;
        window.BackColor = Color.FromArgb(22, 22, 26);
        window.ForeColor = Color.Gainsboro;

        Label title = new Label();
        title.Text = "GTA6 - VIctory (DexNom RayTime)";
        title.Font = new Font("Segoe UI", 12f, FontStyle.Bold);
        title.SetBounds(18, 14, 480, 26);
        window.Controls.Add(title);

        Label info = new Label();
        info.Text = "Runtime, Agility SDK, teclado/mouse e perfis no mesmo arquivo.";
        info.ForeColor = Color.Gray;
        info.SetBounds(20, 42, 480, 18);
        window.Controls.Add(info);

        play1080 = MakeButton("JOGAR 1080p", 18, 72, 240, 48);
        play1080.Click += delegate { Play(false); };
        play1440 = MakeButton("JOGAR 1440p", 266, 72, 240, 48);
        play1440.Click += delegate { Play(true); };

        Button warm = MakeButton("Aquecer cache", 18, 132, 150, 30);
        warm.Click += delegate { Warm(); };
        Button controls = MakeButton("Controles", 176, 132, 110, 30);
        controls.Click += delegate { OpenFile("CONTROLES.md"); };
        Button logs = MakeButton("Logs", 294, 132, 90, 30);
        logs.Click += delegate { OpenFolder("logs"); };
        Button game = MakeButton("Jogo", 392, 132, 110, 30);
        game.Click += delegate { if (AskGame()) UpdateStatus(); };
        Button tuning = MakeButton("Otimizações", 18, 168, 110, 26);
        tuning.Click += delegate { OpenFile("OTIMIZACOES.md"); };

        status = new Label();
        status.ForeColor = Color.Silver;
        status.SetBounds(20, 204, 482, 110);
        window.Controls.Add(status);

        focus = new Timer();
        focus.Interval = 500;
        focus.Tick += delegate { FocusGame(); };

        UpdateStatus();
    }

    static Button MakeButton(string text, int x, int y, int width, int height)
    {
        Button button = new Button();
        button.Text = text;
        button.SetBounds(x, y, width, height);
        button.FlatStyle = FlatStyle.Flat;
        button.FlatAppearance.BorderColor = Color.FromArgb(70, 70, 80);
        button.BackColor = Color.FromArgb(38, 38, 46);
        button.ForeColor = Color.Gainsboro;
        button.Font = new Font("Segoe UI", 9.5f, FontStyle.Bold);
        window.Controls.Add(button);
        return button;
    }

    static void UpdateStatus()
    {
        string game = ReadGamePath();
        string gameLine = File.Exists(game) ? Shorten(game) : "nao configurado";
        long cache = 0;
        try
        {
            foreach (string file in Directory.GetFiles(Path.Combine(Runtime, "cache"), "*", SearchOption.AllDirectories))
            {
                cache += new FileInfo(file).Length;
            }
        }
        catch (Exception)
        {
        }
        status.Text =
            "Runtime: " + Runtime + "\n" +
            "Jogo: " + gameLine + "\n" +
            "Cache: " + (cache / (1024 * 1024)) + " MB\n" +
            "Teclado: WASD + mouse | Esc pausa | Tab mapa";
    }

    static string Shorten(string path)
    {
        return path.Length <= 62 ? path : "..." + path.Substring(path.Length - 59);
    }

    static void FocusGame()
    {
        focusTicks++;
        if (focusTicks < 12)
        {
            return;
        }
        IntPtr handle = IntPtr.Zero;
        if (running != null && !running.HasExited)
        {
            running.Refresh();
            handle = running.MainWindowHandle;
        }
        if (handle == IntPtr.Zero)
        {
            handle = FindWindow("sgaWindowClass", null);
        }
        if (handle != IntPtr.Zero)
        {
            ShowWindow(handle, 9);
            SetForegroundWindow(handle);
            focus.Stop();
        }
        else if (focusTicks > 80)
        {
            focus.Stop();
        }
    }

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr FindWindow(string className, string windowName);

    [DllImport("user32.dll")]
    static extern bool ShowWindow(IntPtr handle, int command);

    [DllImport("user32.dll")]
    static extern bool SetForegroundWindow(IntPtr handle);

    // --------------------------------------------------------------- extras

    static void Warm()
    {
        string exe = Path.Combine(Runtime, "victory-warm.exe");
        ProcessStartInfo start = new ProcessStartInfo(exe);
        start.WorkingDirectory = Runtime;
        start.UseShellExecute = false;
        start.EnvironmentVariables["VICTORY_LOG"] = "warn";
        try
        {
            Process.Start(start);
            status.Text = "Aquecendo o cache de shaders. Pode demorar alguns minutos.";
        }
        catch (Exception error)
        {
            MessageBox.Show(error.Message, "GTA6", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    static void OpenFile(string name)
    {
        string path = Path.Combine(Runtime, name);
        if (File.Exists(path))
        {
            Process.Start(path);
        }
    }

    static void OpenFolder(string name)
    {
        string path = name.Length == 0 ? Runtime : Path.Combine(Runtime, name);
        if (Directory.Exists(path))
        {
            Process.Start("explorer.exe", "\"" + path + "\"");
        }
    }
}
