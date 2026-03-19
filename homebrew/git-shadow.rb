class GitShadow < Formula
  desc "Shadow branch pattern utilities for Git"
  homepage "https://github.com/filozofer/git-shadow"
  url "https://github.com/filozofer/git-shadow/releases/download/v1.0.2/git-shadow-1.0.2.tar.gz"
  sha256 "b826999a09c18e29501eadf7bd8ba2b0c7f4d9a5d860551223e1910f349daa8a"
  version "1.0.2"
  license "MIT"

  # No dependencies beyond bash and git (both already required by Homebrew).

  def install
    # Make all shell scripts executable before installing.
    Dir["commands/**/*.sh", "lib/*.sh", "scripts/*.sh"].each do |f|
      chmod 0755, f
    end

    # Install the toolkit directory structure under the Cellar prefix.
    # bin/git-shadow resolves TOOL_ROOT as prefix/ (one level up from bin/).
    prefix.install "commands", "config", "lib", "scripts", "VERSION"
    (prefix/"bin").install "bin/git-shadow"
    chmod 0755, prefix/"bin/git-shadow"

    # Expose the binary via a Homebrew-managed symlink in $(brew --prefix)/bin.
    bin.install_symlink prefix/"bin/git-shadow"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/git-shadow version")
  end
end
