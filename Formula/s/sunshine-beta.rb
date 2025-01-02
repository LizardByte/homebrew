require "language/node"

class SunshineBeta < Formula
  conflicts_with "sunshine", because: "sunshine and sunshine-beta cannot be installed at the same time"
  desc "Self-hosted game stream host for Moonlight"
  homepage "https://app.lizardbyte.dev/Sunshine"
  url "https://github.com/LizardByte/Sunshine.git",
    tag: "v2025.102.32311"
  version "2025.102.32311"
  license all_of: ["GPL-3.0-only"]
  head "https://github.com/LizardByte/Sunshine.git", branch: "master"

  # https://docs.brew.sh/Brew-Livecheck#githublatest-strategy-block
  livecheck do
    url :stable
    regex(/^v?(\d+\.\d+\.\d+)$/i)
    strategy :github_latest do |json, regex|
      match = json["tag_name"]&.match(regex)
      next if match.blank?

      match[1]
    end
  end

  option "with-docs", "Enable docs"
  option "with-static-boost", "Enable static link of Boost libraries"
  option "without-static-boost", "Disable static link of Boost libraries" # default option

  depends_on "cmake" => :build
  depends_on "doxygen" => :build
  depends_on "graphviz" => :build
  depends_on "node" => :build
  depends_on "pkg-config" => :build
  depends_on "curl"
  depends_on "miniupnpc"
  depends_on "openssl"
  depends_on "opus"
  depends_on "boost" => :recommended
  depends_on "icu4c" => :recommended

  on_linux do
    depends_on "avahi"
    depends_on "libcap"
    depends_on "libdrm"
    depends_on "libnotify"
    depends_on "libva"
    depends_on "libx11"
    depends_on "libxcb"
    depends_on "libxcursor"
    depends_on "libxfixes"
    depends_on "libxi"
    depends_on "libxinerama"
    depends_on "libxrandr"
    depends_on "libxtst"
    depends_on "numactl"
    depends_on "pulseaudio"
    depends_on "systemd"
    depends_on "wayland"
  end

  def install
    ENV["BRANCH"] = "master"
    ENV["BUILD_VERSION"] = "v2025.102.32311"
    ENV["COMMIT"] = "d50611c79bd8d49b88fa52456c1522b7845300f9"

    args = %W[
      -DBUILD_WERROR=ON
      -DCMAKE_INSTALL_PREFIX=#{prefix}
      -DHOMEBREW_ALLOW_FETCHCONTENT=ON
      -DOPENSSL_ROOT_DIR=#{Formula["openssl"].opt_prefix}
      -DSUNSHINE_ASSETS_DIR=sunshine/assets
      -DSUNSHINE_BUILD_HOMEBREW=ON
      -DSUNSHINE_ENABLE_TRAY=OFF
      -DSUNSHINE_PUBLISHER_NAME='LizardByte'
      -DSUNSHINE_PUBLISHER_WEBSITE='https://app.lizardbyte.dev'
      -DSUNSHINE_PUBLISHER_ISSUE_URL='https://app.lizardbyte.dev/support'
    ]

    if build.with? "docs"
      ohai "Building docs: enabled"
      args << "-DBUILD_DOCS=ON"
    else
      ohai "Building docs: disabled"
      args << "-DBUILD_DOCS=OFF"
    end

    if build.without? "static-boost"
      args << "-DBOOST_USE_STATIC=OFF"
      ohai "Disabled statically linking Boost libraries"
    else
      args << "-DBOOST_USE_STATIC=ON"
      ohai "Enabled statically linking Boost libraries"

      unless Formula["icu4c"].any_version_installed?
        odie <<~EOS
          icu4c must be installed to link against static Boost libraries,
          either install icu4c or use brew install sunshine --with-static-boost instead
        EOS
      end
      ENV.append "CXXFLAGS", "-I#{Formula["icu4c"].opt_include}"
      icu4c_lib_path = Formula["icu4c"].opt_lib.to_s
      ENV.append "LDFLAGS", "-L#{icu4c_lib_path}"
      ENV["LIBRARY_PATH"] = icu4c_lib_path
      ohai "Linking against ICU libraries at: #{icu4c_lib_path}"
    end

    args << "-DCUDA_FAIL_ON_MISSING=OFF" if OS.linux?

    system "cmake", "-S", ".", "-B", "build", *std_cmake_args, *args

    cd "build" do
      system "make"
      system "make", "install"

      bin.install "tests/test_sunshine"
    end

    # codesign the binary on intel macs
    system "codesign", "-s", "-", "--force", "--deep", bin/"sunshine" if OS.mac? && Hardware::CPU.intel?

    bin.install "src_assets/linux/misc/postinst" if OS.linux?
  end

  service do
    run [opt_bin/"sunshine", "~/.config/sunshine/sunshine.conf"]
  end

  def caveats
    caveats_message = <<~EOS
      Thanks for installing Sunshine!

      To get started, review the documentation at:
        https://docs.lizardbyte.dev/projects/sunshine/en/latest/
    EOS

    if OS.linux?
      caveats_message += <<~EOS
        ATTENTION: To complete installation, you must run the following command:
        `sudo #{bin}/postinst`
      EOS
    end

    if OS.mac?
      caveats_message += <<~EOS
        Sunshine can only access microphones on macOS due to system limitations.
        To stream system audio use "Soundflower" or "BlackHole".

        Gamepads are not currently supported on macOS.
      EOS
    end

    caveats_message
  end

  test do
    # test that the binary runs at all
    system bin/"sunshine", "--version"

    # run the test suite
    system bin/"test_sunshine", "--gtest_color=yes"
  end
end
