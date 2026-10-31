using System.Diagnostics;
using System.Drawing;

namespace AbonaFlemoonServerManager;

internal sealed class MainForm : Form
{
    private readonly ServerSupervisor _supervisor;
    private readonly TunnelSupervisor _tunnelSupervisor;
    private readonly bool _startInBackground;
    private readonly Label _statusLabel = new();
    private readonly Panel _statusDot = new();
    private readonly TextBox _localUrl = new();
    private readonly TextBox _networkUrls = new();
    private readonly TextBox _log = new();
    private readonly Button _startButton = new();
    private readonly Button _stopButton = new();
    private readonly Button _restartButton = new();
    private readonly CheckBox _chkAutoStart = new();
    private readonly NotifyIcon _tray = new();
    private readonly EventWaitHandle _showWindowEvent;
    private bool _allowExit;

    public MainForm(ServerSupervisor supervisor, bool startInBackground)
    {
        _supervisor = supervisor;
        _tunnelSupervisor = new TunnelSupervisor(_supervisor.InstallRoot);
        _startInBackground = startInBackground;
        _showWindowEvent = new EventWaitHandle(false, EventResetMode.AutoReset, Program.ShowWindowEventName);
        BuildUi();
        BuildTray();
        _ = Handle;
        _ = Task.Run(ListenForShowWindowRequestsAsync);
        _supervisor.StatusChanged += SupervisorOnStatusChanged;
        _supervisor.LogReceived += SupervisorOnLogReceived;
        Shown += OnShown;
        FormClosing += OnFormClosing;
    }

    private async Task ListenForShowWindowRequestsAsync()
    {
        while (!IsDisposed)
        {
            try
            {
                if (_showWindowEvent.WaitOne(1000))
                {
                    if (!IsDisposed)
                    {
                        RunOnUi(ShowWindow);
                    }
                }
            }
            catch
            {
                await Task.Delay(500);
            }
        }
    }

    private void BuildUi()
    {
        Text = "مدير سيرفر Church Membership - العضوية الكنسية - Church Membership Server Manager";
        RightToLeft = RightToLeft.Yes;
        RightToLeftLayout = true;
        StartPosition = FormStartPosition.CenterScreen;
        MinimumSize = new Size(780, 580);
        Size = new Size(880, 670);
        BackColor = Color.FromArgb(242, 246, 252);
        Font = new Font("Tahoma", 10F);

        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            Padding = new Padding(24),
            RowCount = 7,
            ColumnCount = 1,
        };
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 68));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 68));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 64));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 88));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 36));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 64));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        Controls.Add(root);

        root.Controls.Add(new Label
        {
            Text = "مدير سيرفر Church Membership - العضوية الكنسية",
            Dock = DockStyle.Fill,
            Font = new Font("Tahoma", 20F, FontStyle.Bold),
            ForeColor = Color.FromArgb(26, 35, 126),
            TextAlign = ContentAlignment.MiddleRight,
        }, 0, 0);

        var statusPanel = new Panel
        {
            Dock = DockStyle.Fill,
            BackColor = Color.White,
            Padding = new Padding(18),
        };
        _statusDot.Size = new Size(18, 18);
        _statusDot.Location = new Point(statusPanel.Width - 38, 24);
        _statusDot.Anchor = AnchorStyles.Top | AnchorStyles.Right;
        _statusDot.BackColor = Color.Gray;
        _statusLabel.Text = "جاري فحص السيرفر وقاعدة بيانات PostgreSQL...";
        _statusLabel.Dock = DockStyle.Fill;
        _statusLabel.Padding = new Padding(0, 0, 34, 0);
        _statusLabel.Font = new Font("Tahoma", 12F, FontStyle.Bold);
        _statusLabel.TextAlign = ContentAlignment.MiddleRight;
        statusPanel.Controls.Add(_statusLabel);
        statusPanel.Controls.Add(_statusDot);
        root.Controls.Add(statusPanel, 0, 1);

        _localUrl.ReadOnly = true;
        _localUrl.Text = _supervisor.LocalUrl;
        _localUrl.Font = new Font("Consolas", 11F, FontStyle.Bold);
        _localUrl.TextAlign = HorizontalAlignment.Left;
        root.Controls.Add(AddressRow("العنوان المحلي (هذا الجهاز)", _localUrl), 0, 2);

        _networkUrls.ReadOnly = true;
        _networkUrls.Multiline = true;
        _networkUrls.Text = _supervisor.NetworkUrls.Count == 0
            ? "لا يوجد عنوان شبكة متاح"
            : string.Join(Environment.NewLine, _supervisor.NetworkUrls);
        _networkUrls.Font = new Font("Consolas", 10F, FontStyle.Bold);
        _networkUrls.TextAlign = HorizontalAlignment.Left;
        root.Controls.Add(AddressRow("عناوين الأجهزة الأخرى والموبايل", _networkUrls), 0, 3);

        _chkAutoStart.Text = "التشغيل التلقائي للسيرفر في الخلفية عند بدء تشغيل Windows";
        _chkAutoStart.Dock = DockStyle.Fill;
        _chkAutoStart.Font = new Font("Tahoma", 9.5F);
        _chkAutoStart.ForeColor = Color.FromArgb(40, 50, 70);
        _chkAutoStart.Checked = _supervisor.IsAutoStartEnabled();
        _chkAutoStart.CheckedChanged += (_, _) =>
        {
            _supervisor.SetAutoStartWithWindows(_chkAutoStart.Checked);
        };
        root.Controls.Add(_chkAutoStart, 0, 4);

        var buttons = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            FlowDirection = FlowDirection.RightToLeft,
            Padding = new Padding(0, 10, 0, 6),
        };
        ConfigureButton(_startButton, "تشغيل السيرفر", Color.FromArgb(34, 125, 82),
            async () => await _supervisor.StartAsync());
        ConfigureButton(_restartButton, "إعادة التشغيل", Color.FromArgb(26, 35, 126),
            async () => await _supervisor.RestartAsync());
        ConfigureButton(_stopButton, "إيقاف السيرفر", Color.FromArgb(190, 65, 65),
            async () => await _supervisor.StopAsync());

        var tunnelButton = new Button
        {
            Text = "الربط الخارجي والأنفاق",
            Width = 180,
            Height = 42,
            BackColor = Color.FromArgb(108, 71, 153),
            ForeColor = Color.White,
            FlatStyle = FlatStyle.Flat,
            Font = new Font("Tahoma", 10F, FontStyle.Bold),
            Cursor = Cursors.Hand,
        };
        tunnelButton.FlatAppearance.BorderSize = 0;
        tunnelButton.Click += (_, _) =>
        {
            using var form = new TunnelManagerForm(_tunnelSupervisor, _supervisor);
            form.ShowDialog(this);
        };

        buttons.Controls.AddRange([_startButton, _restartButton, _stopButton, tunnelButton]);
        root.Controls.Add(buttons, 0, 5);

        _log.Dock = DockStyle.Fill;
        _log.Multiline = true;
        _log.ReadOnly = true;
        _log.ScrollBars = ScrollBars.Vertical;
        _log.BackColor = Color.FromArgb(31, 41, 45);
        _log.ForeColor = Color.Gainsboro;
        _log.Font = new Font("Consolas", 9F);
        _log.RightToLeft = RightToLeft.No;
        root.Controls.Add(_log, 0, 6);
    }

    private Panel AddressRow(string title, TextBox value)
    {
        var panel = new Panel { Dock = DockStyle.Fill, Padding = new Padding(0, 8, 0, 4) };
        var copy = new Button
        {
            Text = "نسخ",
            Dock = DockStyle.Left,
            Width = 76,
            FlatStyle = FlatStyle.Flat,
            BackColor = Color.White,
            Cursor = Cursors.Hand,
        };
        copy.Click += (_, _) =>
        {
            var text = value.SelectedText.Length > 0 ? value.SelectedText : value.Text;
            if (!string.IsNullOrWhiteSpace(text)) Clipboard.SetText(text.Trim());
        };
        var label = new Label
        {
            Text = title,
            Dock = DockStyle.Right,
            Width = 190,
            TextAlign = ContentAlignment.MiddleRight,
            Font = new Font("Tahoma", 10F, FontStyle.Bold),
        };
        value.Dock = DockStyle.Fill;
        panel.Controls.Add(value);
        panel.Controls.Add(copy);
        panel.Controls.Add(label);
        return panel;
    }

    private static void ConfigureButton(Button button, string text, Color color, Func<Task> action)
    {
        button.Text = text;
        button.Size = new Size(150, 42);
        button.Margin = new Padding(8, 0, 0, 0);
        button.FlatStyle = FlatStyle.Flat;
        button.FlatAppearance.BorderSize = 0;
        button.BackColor = color;
        button.ForeColor = Color.White;
        button.Cursor = Cursors.Hand;
        button.Click += async (_, _) => await action();
    }

    private void BuildTray()
    {
        var iconPath = Path.Combine(AppContext.BaseDirectory, "app_icon.ico");
        _tray.Icon = File.Exists(iconPath) ? new Icon(iconPath) : SystemIcons.Application;
        _tray.Text = "مدير سيرفر العضوية الكنسية";
        _tray.Visible = true;
        _tray.DoubleClick += (_, _) => ShowWindow();

        var menu = new ContextMenuStrip { RightToLeft = RightToLeft.Yes };
        menu.Items.Add("فتح مدير السيرفر", null, (_, _) => ShowWindow());
        menu.Items.Add("تشغيل", null, async (_, _) => await _supervisor.StartAsync());
        menu.Items.Add("إعادة التشغيل", null, async (_, _) => await _supervisor.RestartAsync());
        menu.Items.Add("إيقاف", null, async (_, _) => await _supervisor.StopAsync());
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("الربط الخارجي والأنفاق (Tunnels)", null, (_, _) =>
        {
            using var form = new TunnelManagerForm(_tunnelSupervisor, _supervisor);
            form.ShowDialog();
        });
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("فتح سجل التشغيل", null, (_, _) => OpenPath(_supervisor.ManagerLogPath));
        menu.Items.Add("فتح مجلد بيانات السيرفر", null, (_, _) => OpenPath(_supervisor.ServerData));
        menu.Items.Add("خروج", null, async (_, _) => await ExitApplicationAsync());
        _tray.ContextMenuStrip = menu;
    }

    private static void OpenPath(string path)
    {
        if (File.Exists(path) || Directory.Exists(path))
        {
            Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
        }
    }

    private async void OnShown(object? sender, EventArgs eventArgs)
    {
        if (_startInBackground) Hide();
        await _supervisor.StartAsync();
    }

    private void OnFormClosing(object? sender, FormClosingEventArgs eventArgs)
    {
        if (_allowExit) return;
        eventArgs.Cancel = true;
        Hide();
        _tray.ShowBalloonTip(
            1800,
            "مدير سيرفر العضوية الكنسية",
            "السيرفر مستمر في العمل في الخلفية بجانب الساعة.",
            ToolTipIcon.Info);
    }

    private void SupervisorOnStatusChanged(object? sender, ServerStatusEventArgs eventArgs)
    {
        RunOnUi(() =>
        {
            _statusLabel.Text = eventArgs.Message;
            _statusDot.BackColor = eventArgs.State switch
            {
                ServerState.Running => Color.FromArgb(25, 160, 95),
                ServerState.Failed => Color.FromArgb(210, 55, 55),
                ServerState.Stopped => Color.Gray,
                _ => Color.FromArgb(230, 155, 35),
            };
            var busy = eventArgs.State is ServerState.Starting
                or ServerState.Stopping
                or ServerState.Recovering;
            _startButton.Enabled = !busy;
            _stopButton.Enabled = !busy;
            _restartButton.Enabled = !busy;
            var trayText = eventArgs.State == ServerState.Running
                ? "سيرفر العضوية الكنسية: يعمل"
                : $"سيرفر العضوية الكنسية: {eventArgs.Message}";
            _tray.Text = trayText[..Math.Min(63, trayText.Length)];
        });
    }

    private void SupervisorOnLogReceived(object? sender, string line)
    {
        RunOnUi(() =>
        {
            _log.AppendText(line + Environment.NewLine);
            if (_log.TextLength > 50000) _log.Text = _log.Text[^35000..];
            _log.SelectionStart = _log.TextLength;
            _log.ScrollToCaret();
        });
    }

    private void RunOnUi(Action action)
    {
        if (IsDisposed) return;
        if (!IsHandleCreated) return;
        void Apply() { if (!IsDisposed && !Disposing) action(); }
        try { if (InvokeRequired) BeginInvoke((Action)Apply); else Apply(); }
        catch (InvalidOperationException) when (IsDisposed || Disposing || !IsHandleCreated) { }
    }

    private void ShowWindow()
    {
        Show();
        WindowState = FormWindowState.Normal;
        TopMost = true;
        Activate();
        BringToFront();
        TopMost = false;
    }

    private async Task ExitApplicationAsync()
    {
        _tunnelSupervisor.StopTunnel();
        await _supervisor.StopAsync();
        _allowExit = true;
        _tray.Visible = false;
        Close();
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _tray.Dispose();
            _tunnelSupervisor.Dispose();
            _showWindowEvent.Dispose();
        }
        base.Dispose(disposing);
    }
}
