class GitRefresh < Formula
  desc "Keep every branch rebased onto the right base, in a worktree per branch"
  homepage "https://github.com/gregswift/git-refresh"
  license "MIT"
  url "https://github.com/gregswift/git-refresh/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "26c7442158c6ee92a56275c8662c9516803ca434e0575893df2f872441b01ff0"
  head "https://github.com/gregswift/git-refresh.git", branch: "main"

  # git 2.37 for push.autoSetupRemote, which the workflow recommends; the
  # scripts themselves need 2.23 for `git branch --show-current`. Apple's git
  # is usually old enough to matter.
  depends_on "git"

  def install
    system "make", "install", "PREFIX=#{prefix}"
  end

  def caveats
    <<~EOS
      Two optional pieces are not wired up automatically.

      `gwt` has to be a shell function, because only your own shell can cd.
      Add to ~/.bashrc or ~/.zshrc:
        . #{opt_share}/git-refresh/gwt.sh

      The aliases (check-trees, prune-trees, commend, please) are a gitconfig
      you include, so renames reach you:
        git config --global include.path #{opt_share}/git-refresh/refresh.gitconfig

      Start here:
        #{opt_share}/doc/git-refresh/WORKFLOWS.md
    EOS
  end

  test do
    assert_match "Usage: git refresh", shell_output("#{bin}/git-refresh --help")
    assert_match "Usage: git new-worktree", shell_output("#{bin}/git-new-worktree --help")
    assert_match "Usage: git clone-for-worktrees",
                 shell_output("#{bin}/git-clone-for-worktrees --help")
  end
end
