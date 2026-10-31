using System.Drawing;

namespace AbonaFlemoonServerManager;

internal sealed class TunnelManagerForm : Form
{
    private readonly TunnelSupervisor _tunnelSupervisor;
    private readonly ServerSupervisor _serverSupervisor;

    private readonly RadioButton _optCloudflareQuick = new();
    private readonly RadioButton _optCloudflareStable = new();
    private readonly RadioButton _optNgrok = new();
    private readonly RadioButton _optLocalLan = new();

    private readonly Panel _panelQuick = new();
    private readonly Panel _panelStable = new();
    private readonly Panel _panelNgrok = new();
    private readonly Panel _panelLan = new();

    private readonly TextBox _txtNgrokToken = new();
    private readonly TextBox _txtNgrokDomain = new();
    private readonly TextBox _txtCloudflareToken = new();

    private readonly TextBox _txtPublicUrl = new();
    private readonly Button _btnCopyUrl = new();
    private readonly Label _lblStatus = new();
    private readonly Panel _pnlStatusDot = new();
    private readonly TextBox _txtLogs = new();

    private readonly Button _btnStartStop = new();
    private readonly Button _btnCloudflared = new();
    private readonly Button _btnInstallCfService = new();
    private readonly Button _btnUninstallCfService = new();

    public TunnelManagerForm(TunnelSupervisor tunnelSupervisor, ServerSupervisor serverSupervisor)
    {
        _tunnelSupervisor = tunnelSupervisor;
        _serverSupervisor = serverSupervisor;

        BuildUi();
        LoadConfigValues();

        // Events can arrive before ShowDialog and after this dialog closes.
        _ = Handle;
        _tunnelSupervisor.UrlDetected += OnUrlDetected;
        _tunnelSupervisor.LogReceived += OnLogReceived;
        _tunnelSupervisor.StatusChanged += OnTunnelStatusChanged;

        FormClosing += (_, _) => SaveConfigValues();
    }

    private void OnUrlDetected(object? sender, string url) => RunOnUi(() =>
    {
        _txtPublicUrl.Text = url;
        UpdateStatus(true, $"متصل على الرابط: {url}");
    });

    private void OnLogReceived(object? sender, string message) => RunOnUi(() =>
        _txtLogs.AppendText($"[{DateTime.Now:HH:mm:ss}] {message}{Environment.NewLine}"));

    private void OnTunnelStatusChanged(object? sender, bool running) => RunOnUi(UpdateButtonsState);

    private void RunOnUi(Action action)
    {
        if (IsDisposed || Disposing || !IsHandleCreated) return;
        void Apply() { if (!IsDisposed && !Disposing) action(); }
        try { if (InvokeRequired) BeginInvoke((Action)Apply); else Apply(); }
        catch (InvalidOperationException) when (IsDisposed || Disposing || !IsHandleCreated) { }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _tunnelSupervisor.UrlDetected -= OnUrlDetected;
            _tunnelSupervisor.LogReceived -= OnLogReceived;
            _tunnelSupervisor.StatusChanged -= OnTunnelStatusChanged;
        }
        base.Dispose(disposing);
    }

    private void BuildUi()
    {
        Text = "إعدادات الربط السحابي والشبكة — Church Membership - العضوية الكنسية";
        RightToLeft = RightToLeft.Yes;
        RightToLeftLayout = true;
        StartPosition = FormStartPosition.CenterScreen;
        MinimumSize = new Size(820, 680);
        Size = new Size(880, 720);
        BackColor = Color.FromArgb(242, 246, 252);
        Font = new Font("Tahoma", 9.5F);

        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            Padding = new Padding(20),
            RowCount = 6,
            ColumnCount = 1,
        };
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 50));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 55));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 85));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 185));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 55));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        Controls.Add(root);

        root.Controls.Add(new Label
        {
            Text = "اختيار قناة الربط والاتصال الخارجي للموبايل والكمبيوتر (SignalR & API)",
            Dock = DockStyle.Fill,
            Font = new Font("Tahoma", 15F, FontStyle.Bold),
            ForeColor = Color.FromArgb(26, 35, 126),
            TextAlign = ContentAlignment.MiddleRight,
        }, 0, 0);

        var urlPanel = new Panel
        {
            Dock = DockStyle.Fill,
            BackColor = Color.White,
            Padding = new Padding(12),
        };
        _pnlStatusDot.Size = new Size(14, 14);
        _pnlStatusDot.Location = new Point(12, 18);
        _pnlStatusDot.BackColor = Color.Gray;

        _lblStatus.Text = "النفق غير متصل حالياً";
        _lblStatus.Location = new Point(34, 15);
        _lblStatus.Size = new Size(240, 24);
        _lblStatus.Font = new Font("Tahoma", 9.5F, FontStyle.Bold);
        _lblStatus.ForeColor = Color.DimGray;

        _btnCopyUrl.Text = "نسخ الرابط";
        _btnCopyUrl.Dock = DockStyle.Right;
        _btnCopyUrl.Width = 90;
        _btnCopyUrl.BackColor = Color.FromArgb(26, 35, 126);
        _btnCopyUrl.ForeColor = Color.White;
        _btnCopyUrl.FlatStyle = FlatStyle.Flat;
        _btnCopyUrl.Cursor = Cursors.Hand;
        _btnCopyUrl.Click += (_, _) =>
        {
            if (!string.IsNullOrWhiteSpace(_txtPublicUrl.Text))
            {
                Clipboard.SetText(_txtPublicUrl.Text.Trim());
                MessageBox.Show("تم نسخ الرابط إلى الحافظة بنجاح!", "تم النسخ", MessageBoxButtons.OK,
                    MessageBoxIcon.Information);
            }
        };

        _txtPublicUrl.Dock = DockStyle.Fill;
        _txtPublicUrl.ReadOnly = true;
        _txtPublicUrl.Font = new Font("Consolas", 11F, FontStyle.Bold);
        _txtPublicUrl.TextAlign = HorizontalAlignment.Left;
        _txtPublicUrl.RightToLeft = RightToLeft.No;

        urlPanel.Controls.Add(_txtPublicUrl);
        urlPanel.Controls.Add(_btnCopyUrl);
        urlPanel.Controls.Add(_lblStatus);
        urlPanel.Controls.Add(_pnlStatusDot);
        root.Controls.Add(urlPanel, 0, 1);

        var radioGrid = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            RowCount = 2,
            ColumnCount = 2,
            Padding = new Padding(0, 4, 0, 4),
        };
        radioGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));
        radioGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50F));
        radioGrid.RowStyles.Add(new RowStyle(SizeType.Percent, 50F));
        radioGrid.RowStyles.Add(new RowStyle(SizeType.Percent, 50F));

        _optNgrok.Text = "🚀 نفق Ngrok (دومين حسابك إن وجد)";
        _optNgrok.Dock = DockStyle.Fill;
        _optNgrok.Font = new Font("Tahoma", 10F, FontStyle.Bold);
        _optNgrok.ForeColor = Color.FromArgb(20, 50, 130);
        _optNgrok.CheckedChanged += (_, _) => OnModeChanged();

        _optCloudflareQuick.Text = "🌐 Cloudflare Quick (فوري ومجاني بدون حساب)";
        _optCloudflareQuick.Dock = DockStyle.Fill;
        _optCloudflareQuick.Font = new Font("Tahoma", 10F, FontStyle.Bold);
        _optCloudflareQuick.ForeColor = Color.FromArgb(20, 80, 110);
        _optCloudflareQuick.CheckedChanged += (_, _) => OnModeChanged();

        _optCloudflareStable.Text = "🔒 Cloudflare Stable (نفق دائم 24/7 كخدمة)";
        _optCloudflareStable.Dock = DockStyle.Fill;
        _optCloudflareStable.Font = new Font("Tahoma", 10F, FontStyle.Bold);
        _optCloudflareStable.ForeColor = Color.FromArgb(60, 60, 70);
        _optCloudflareStable.CheckedChanged += (_, _) => OnModeChanged();

        _optLocalLan.Text = "🏠 الشبكة المحلية فقط (LAN IP بدون إنترنت)";
        _optLocalLan.Dock = DockStyle.Fill;
        _optLocalLan.Font = new Font("Tahoma", 10F, FontStyle.Bold);
        _optLocalLan.ForeColor = Color.FromArgb(50, 80, 50);
        _optLocalLan.CheckedChanged += (_, _) => OnModeChanged();

        radioGrid.Controls.Add(_optNgrok, 0, 0);
        radioGrid.Controls.Add(_optCloudflareQuick, 1, 0);
        radioGrid.Controls.Add(_optCloudflareStable, 0, 1);
        radioGrid.Controls.Add(_optLocalLan, 1, 1);
        root.Controls.Add(radioGrid, 0, 2);

        var configContainer = new Panel { Dock = DockStyle.Fill };
        SetupQuickPanel();
        SetupStablePanel();
        SetupNgrokPanel();
        SetupLanPanel();
        configContainer.Controls.AddRange([_panelQuick, _panelStable, _panelNgrok, _panelLan]);
        root.Controls.Add(configContainer, 0, 3);

        var actionPanel = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            FlowDirection = FlowDirection.RightToLeft,
            Padding = new Padding(0, 8, 0, 0),
        };

        _btnStartStop.Text = "تشغيل النفق";
        _btnStartStop.Size = new Size(160, 42);
        _btnStartStop.BackColor = Color.FromArgb(34, 125, 82);
        _btnStartStop.ForeColor = Color.White;
        _btnStartStop.Font = new Font("Tahoma", 10F, FontStyle.Bold);
        _btnStartStop.FlatStyle = FlatStyle.Flat;
        _btnStartStop.Cursor = Cursors.Hand;
        _btnStartStop.Click += async (_, _) => await HandleStartStopClick();

        actionPanel.Controls.Add(_btnStartStop);
        _btnCloudflared.Text = "فحص / تنزيل Cloudflared";
        _btnCloudflared.Size = new Size(200, 42);
        _btnCloudflared.BackColor = Color.FromArgb(26, 35, 126);
        _btnCloudflared.ForeColor = Color.White;
        _btnCloudflared.FlatStyle = FlatStyle.Flat;
        _btnCloudflared.Click += async (_, _) =>
        {
            _btnCloudflared.Enabled = false;
            try
            {
                var path = await _tunnelSupervisor.EnsureToolAsync("cloudflared");
                _txtLogs.AppendText($"[{DateTime.Now:HH:mm:ss}] Cloudflared جاهز: {path}{Environment.NewLine}");
                MessageBox.Show("أداة Cloudflared جاهزة. يمكنك تشغيل النفق الآن.", "برنامج العضوية الكنسية",
                    MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"تعذر تنزيل Cloudflared: {ex.Message}", "برنامج العضوية الكنسية",
                    MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally { _btnCloudflared.Enabled = true; }
        };
        actionPanel.Controls.Add(_btnCloudflared);
        root.Controls.Add(actionPanel, 0, 4);

        _txtLogs.Dock = DockStyle.Fill;
        _txtLogs.Multiline = true;
        _txtLogs.ReadOnly = true;
        _txtLogs.ScrollBars = ScrollBars.Vertical;
        _txtLogs.BackColor = Color.FromArgb(28, 35, 42);
        _txtLogs.ForeColor = Color.LightGreen;
        _txtLogs.Font = new Font("Consolas", 9F);
        _txtLogs.RightToLeft = RightToLeft.No;
        root.Controls.Add(_txtLogs, 0, 5);

        _optCloudflareQuick.Checked = true;
    }

    private void SetupQuickPanel()
    {
        _panelQuick.Dock = DockStyle.Fill;
        _panelQuick.BackColor = Color.White;
        _panelQuick.Padding = new Padding(14);
        var lbl = new Label
        {
            Text = "• يقوم بإنشاء رابط سريع فوري تلقائياً عبر نطاق trycloudflare.com.\n" +
                   "• لا يتطلب أي حساب أو دومين مدفوع، ويعمل مباشرة عبر الإنترنت مع SignalR.\n" +
                   "• يتم تنزيل أداة cloudflared تلقائياً عند أول تشغيل إذا لم تكن موجودة على الجهاز.\n" +
                   "• انسخ الرابط الظاهر بالأعلى وضعه في إعدادات الاتصال في تطبيق برنامج العضوية الكنسية على أي جهاز أو موبايل.",
            Dock = DockStyle.Fill,
            Font = new Font("Tahoma", 9.5F),
            ForeColor = Color.FromArgb(50, 60, 70),
        };
        _panelQuick.Controls.Add(lbl);
    }

    private void SetupStablePanel()
    {
        _panelStable.Dock = DockStyle.Fill;
        _panelStable.BackColor = Color.White;
        _panelStable.Padding = new Padding(14);

        var lbl = new Label
        {
            Text = "كود النفق الدائم (Cloudflare Zero Trust Tunnel Token):",
            Location = new Point(14, 12),
            AutoSize = true,
            Font = new Font("Tahoma", 9.5F, FontStyle.Bold),
        };
        _txtCloudflareToken.Location = new Point(14, 38);
        _txtCloudflareToken.Size = new Size(620, 27);
        _txtCloudflareToken.Font = new Font("Consolas", 10F);
        _txtCloudflareToken.RightToLeft = RightToLeft.No;

        _btnInstallCfService.Text = "تثبيت كخدمة ويندوز 24/7";
        _btnInstallCfService.Location = new Point(14, 75);
        _btnInstallCfService.Size = new Size(180, 36);
        _btnInstallCfService.BackColor = Color.FromArgb(26, 35, 126);
        _btnInstallCfService.ForeColor = Color.White;
        _btnInstallCfService.FlatStyle = FlatStyle.Flat;
        _btnInstallCfService.Click += async (_, _) =>
        {
            if (string.IsNullOrWhiteSpace(_txtCloudflareToken.Text))
            {
                MessageBox.Show("يرجى إدخال رمز Token الخاص بنفق Cloudflare.", "تنبيه", MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);
                return;
            }
            try
            {
                var res = await _tunnelSupervisor.InstallCloudflareServiceAsync(_txtCloudflareToken.Text);
                MessageBox.Show(res, "نتيجة التثبيت", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "خطأ في التثبيت", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        };

        _btnUninstallCfService.Text = "إلغاء تثبيت الخدمة";
        _btnUninstallCfService.Location = new Point(205, 75);
        _btnUninstallCfService.Size = new Size(150, 36);
        _btnUninstallCfService.BackColor = Color.FromArgb(190, 65, 65);
        _btnUninstallCfService.ForeColor = Color.White;
        _btnUninstallCfService.FlatStyle = FlatStyle.Flat;
        _btnUninstallCfService.Click += async (_, _) =>
        {
            try
            {
                var res = await _tunnelSupervisor.UninstallCloudflareServiceAsync();
                MessageBox.Show(res, "نتيجة إلغاء الخدمة", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "خطأ في إزالة الخدمة", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        };

        _panelStable.Controls.AddRange([lbl, _txtCloudflareToken, _btnInstallCfService, _btnUninstallCfService]);
    }

    private void SetupNgrokPanel()
    {
        _panelNgrok.Dock = DockStyle.Fill;
        _panelNgrok.BackColor = Color.White;
        _panelNgrok.Padding = new Padding(16);

        var layout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            RowCount = 5,
            ColumnCount = 1,
        };
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 26));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 32));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 26));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 32));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));

        var lblToken = new Label
        {
            Text = "رمز التفعيل (Ngrok Auth Token):",
            Dock = DockStyle.Fill,
            Font = new Font("Tahoma", 9.5F, FontStyle.Bold),
            ForeColor = Color.FromArgb(30, 40, 50),
            TextAlign = ContentAlignment.MiddleRight,
        };
        _txtNgrokToken.Dock = DockStyle.Fill;
        _txtNgrokToken.Font = new Font("Consolas", 10.5F);
        _txtNgrokToken.RightToLeft = RightToLeft.No;

        var lblDomain = new Label
        {
            Text = "الدومين الثابت الخاص بك (Static Domain):",
            Dock = DockStyle.Fill,
            Font = new Font("Tahoma", 9.5F, FontStyle.Bold),
            ForeColor = Color.FromArgb(30, 40, 50),
            TextAlign = ContentAlignment.MiddleRight,
        };
        _txtNgrokDomain.Dock = DockStyle.Fill;
        _txtNgrokDomain.PlaceholderText = "دومين ngrok الخاص بك (اختياري)";
        _txtNgrokDomain.Font = new Font("Consolas", 10.5F, FontStyle.Bold);
        _txtNgrokDomain.ForeColor = Color.FromArgb(20, 70, 150);
        _txtNgrokDomain.RightToLeft = RightToLeft.No;

        var lblHint = new Label
        {
            Text = "💡 ملاحظة: عند تشغيل نفق Ngrok بهذا الدومين، يمكن ربط تطبيق الموبايل أو أي جهاز خارج الشبكة مباشرة عبر هذا الرابط الثابت.",
            Dock = DockStyle.Fill,
            Font = new Font("Tahoma", 8.5F),
            ForeColor = Color.FromArgb(90, 100, 110),
            TextAlign = ContentAlignment.TopRight,
        };

        layout.Controls.Add(lblToken, 0, 0);
        layout.Controls.Add(_txtNgrokToken, 0, 1);
        layout.Controls.Add(lblDomain, 0, 2);
        layout.Controls.Add(_txtNgrokDomain, 0, 3);
        layout.Controls.Add(lblHint, 0, 4);

        _panelNgrok.Controls.Add(layout);
    }

    private void SetupLanPanel()
    {
        _panelLan.Dock = DockStyle.Fill;
        _panelLan.BackColor = Color.White;
        _panelLan.Padding = new Padding(14);

        var lbl = new Label
        {
            Text = "عناوين السيرفر على الشبكة المحلية (للأجهزة المتصلة بنفس الراوتر Wi-Fi / LAN):\n\n" +
                   string.Join(Environment.NewLine, _serverSupervisor.NetworkUrls) + "\n\n" +
                   "انسخ أحد هذه العناوين وضعه في نافذة إعدادات الاتصال في تطبيق برنامج العضوية الكنسية.",
            Dock = DockStyle.Fill,
            Font = new Font("Tahoma", 9.5F),
            ForeColor = Color.FromArgb(40, 50, 60),
        };
        _panelLan.Controls.Add(lbl);
    }

    private void OnModeChanged()
    {
        _panelQuick.Visible = _optCloudflareQuick.Checked;
        _panelStable.Visible = _optCloudflareStable.Checked;
        _panelNgrok.Visible = _optNgrok.Checked;
        _panelLan.Visible = _optLocalLan.Checked;

        if (_optLocalLan.Checked)
        {
            _btnStartStop.Visible = false;
            _txtPublicUrl.Text = _serverSupervisor.NetworkUrls.FirstOrDefault() ?? _serverSupervisor.LocalUrl;
            UpdateStatus(true, "الشبكة المحلية جاهزة");
        }
        else if (_optCloudflareStable.Checked)
        {
            _btnStartStop.Visible = false;
            UpdateStatus(false, "خدمة ويندوز مستقلة");
        }
        else
        {
            _btnStartStop.Visible = true;
            UpdateButtonsState();
        }
    }

    private async Task HandleStartStopClick()
    {
        if (_tunnelSupervisor.IsRunning)
        {
            _tunnelSupervisor.StopTunnel();
            UpdateStatus(false, "تم إيقاف النفق");
            _txtPublicUrl.Text = string.Empty;
            return;
        }

        SaveConfigValues();

        try
        {
            _btnStartStop.Enabled = false;
            _btnStartStop.Text = "جاري التجهيز والتحقق...";
            if (_optCloudflareQuick.Checked)
            {
                await _tunnelSupervisor.StartCloudflareQuickAsync();
            }
            else if (_optNgrok.Checked)
            {
                await _tunnelSupervisor.StartNgrokAsync(_txtNgrokDomain.Text, _txtNgrokToken.Text);
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "خطأ في تشغيل النفق", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally
        {
            _btnStartStop.Enabled = true;
            UpdateButtonsState();
        }
    }

    private void UpdateButtonsState()
    {
        if (_tunnelSupervisor.IsRunning)
        {
            _btnStartStop.Text = "إيقاف النفق";
            _btnStartStop.BackColor = Color.FromArgb(190, 65, 65);
            UpdateStatus(true, "النفق يعمل");
        }
        else
        {
            _btnStartStop.Text = "تشغيل النفق";
            _btnStartStop.BackColor = Color.FromArgb(34, 125, 82);
            UpdateStatus(false, "النفق متوقف");
        }
    }

    private void UpdateStatus(bool isGreen, string message)
    {
        _pnlStatusDot.BackColor = isGreen ? Color.FromArgb(46, 175, 105) : Color.Gray;
        _lblStatus.Text = message;
        _lblStatus.ForeColor = isGreen ? Color.FromArgb(20, 120, 60) : Color.DimGray;
    }

    private void LoadConfigValues()
    {
        var cfg = _tunnelSupervisor.Config;
        _txtNgrokToken.Text = cfg.NgrokToken;
        _txtNgrokDomain.Text = cfg.NgrokDomain;
        _txtCloudflareToken.Text = cfg.CloudflareToken;

        switch (cfg.Mode)
        {
            case TunnelMode.CloudflareQuick:
                _optCloudflareQuick.Checked = true;
                break;
            case TunnelMode.CloudflareStable:
                _optCloudflareStable.Checked = true;
                break;
            case TunnelMode.None:
                _optLocalLan.Checked = true;
                break;
            case TunnelMode.Ngrok:
            default:
                _optNgrok.Checked = true;
                break;
        }
    }

    private void SaveConfigValues()
    {
        var cfg = _tunnelSupervisor.Config;
        cfg.NgrokToken = _txtNgrokToken.Text.Trim();
        cfg.NgrokDomain = _txtNgrokDomain.Text.Trim();
        cfg.CloudflareToken = _txtCloudflareToken.Text.Trim();

        if (_optNgrok.Checked) cfg.Mode = TunnelMode.Ngrok;
        else if (_optCloudflareQuick.Checked) cfg.Mode = TunnelMode.CloudflareQuick;
        else if (_optCloudflareStable.Checked) cfg.Mode = TunnelMode.CloudflareStable;
        else cfg.Mode = TunnelMode.None;

        _tunnelSupervisor.SaveConfig();
    }
}
