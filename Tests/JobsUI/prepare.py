"""Generate the isolated UI harness using the current production shared views."""
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
out = Path(tempfile.mkdtemp(prefix='cadenza-jobs-ui-'))
feed = (root / 'Cadenza/Features/Feed/FeedView.swift').read_text()
header = feed[feed.index('struct CadenzaBrowseHeader:'):feed.index('// MARK: - Activity card')]
flow = (root / 'Cadenza/Features/Onboarding/Steps/Step3AffiliationView.swift').read_text().split('struct FlowLayout:')[1]
(out / 'SharedViews.swift').write_text('import SwiftUI\n' + header + '\nstruct FlowLayout:' + flow)
env = dict(os.environ, CADENZA_ROOT=str(root), JOBS_SHARED=str(out / 'SharedViews.swift'))
subprocess.run(['xcodegen', 'generate', '--spec', str(root / 'Tests/JobsUI/project.yml'), '--project', str(out)], env=env, check=True)
print(out)
