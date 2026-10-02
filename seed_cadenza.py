#!/usr/bin/env python3
"""Cadenza cloud DB seed script — 10 musicians, 30 activity posts with images."""

import requests, json, time, uuid, os, sys
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://vcxllrzpolymzylrfscb.supabase.co")
SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")
SEED_PASSWORD = os.environ.get("CADENZA_SEED_PASSWORD", "")

if not SERVICE_KEY or not SEED_PASSWORD:
    raise SystemExit("SUPABASE_SERVICE_KEY and CADENZA_SEED_PASSWORD are required.")
SVC = {"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}", "Content-Type": "application/json"}

_session = requests.Session()
_retry = Retry(total=5, backoff_factor=1.5, status_forcelist=[500, 502, 503, 504])
_session.mount("https://", HTTPAdapter(max_retries=_retry))

def _req(method, url, **kw):
    for attempt in range(4):
        try:
            return _session.request(method, url, timeout=20, **kw)
        except (requests.exceptions.ConnectionError, requests.exceptions.Timeout) as e:
            if attempt == 3:
                raise
            wait = 2 ** attempt
            print(f"    (연결 오류, {wait}초 후 재시도…)")
            time.sleep(wait)

def rest(method, path, **kw):
    r = _req(method, f"{SUPABASE_URL}/rest/v1/{path}", headers=SVC, **kw)
    if not r.ok:
        print(f"  !! {method} {path} → {r.status_code}: {r.text[:200]}")
    return r

def admin(method, path, **kw):
    r = _req(method, f"{SUPABASE_URL}/auth/v1/admin/{path}", headers=SVC, **kw)
    if not r.ok:
        print(f"  !! admin {method} {path} → {r.status_code}: {r.text[:200]}")
    return r

def storage_upload(bucket, path, data, content_type="image/jpeg"):
    url = f"{SUPABASE_URL}/storage/v1/object/{bucket}/{path}"
    r = _req("POST", url, headers={**SVC, "Content-Type": content_type}, data=data)
    if not r.ok:
        print(f"  !! upload {path} → {r.status_code}: {r.text[:200]}")
    return r.ok

# ── 1. 사용자 정의 ─────────────────────────────────────────────────────────────

USERS = [
    dict(email="kim.dohyun@cadenza.app",   pw=SEED_PASSWORD, name="김도현",
         major="기악",   instrument="바이올린",  cities=["서울","베를린"],
         bio="한국예술종합학교 기악과 졸업 후 베를린 한스아이슬러 음악대학에서 수학. 현재 유럽을 중심으로 솔리스트로 활동 중이며, 2023 퀸 엘리자베스 콩쿠르 입상 이후 국제 무대 일정을 병행하고 있습니다.",
         school="한국예술종합학교", course="bachelor", enroll=2015,
         school2="베를린 한스아이슬러 음악대학", course2="master", enroll2=2019),
    dict(email="lee.seoyeon@cadenza.app",  pw=SEED_PASSWORD, name="이서연",
         major="피아노", instrument="피아노",     cities=["서울","파리"],
         bio="연세대학교 음악대학 피아노과 졸업. 파리 국립음악원(CNSMDP)에서 피아노 최고연주자 과정 수료. 쇼팽, 드뷔시, 라벨의 프랑스-폴란드 레퍼토리를 중심으로 유럽 각지에서 리사이틀 활동 중.",
         school="연세대학교 음악대학", course="bachelor", enroll=2014,
         school2="파리 국립음악원", course2="performance", enroll2=2018),
    dict(email="park.junseo@cadenza.app",  pw=SEED_PASSWORD, name="박준서",
         major="기악",   instrument="첼로",       cities=["서울","뉴욕"],
         bio="서울대학교 음악대학을 수석 졸업하고 미국 줄리아드 스쿨에서 석사 학위 취득. 바흐 무반주 첼로 모음곡 전곡 연주를 통해 깊이 있는 해석으로 주목받고 있는 첼리스트.",
         school="서울대학교 음악대학", course="bachelor", enroll=2013,
         school2="줄리아드 스쿨", course2="master", enroll2=2017),
    dict(email="choi.mina@cadenza.app",    pw=SEED_PASSWORD, name="최민아",
         major="기악",   instrument="플루트",     cities=["서울","인디애나폴리스"],
         bio="한국예술종합학교 졸업 후 인디애나 대학교 제이콥스 음악대학에서 수학. 현대음악과 낭만주의 레퍼토리를 넘나드는 다채로운 음악적 언어로 주목받고 있는 플루티스트.",
         school="한국예술종합학교", course="bachelor", enroll=2015,
         school2="인디애나 대학교 제이콥스 음악대학", course2="master", enroll2=2019),
    dict(email="jung.haeun@cadenza.app",   pw=SEED_PASSWORD, name="정하은",
         major="성악",   instrument="소프라노",   cities=["서울","밀라노"],
         bio="이화여자대학교 음악대학 성악과 졸업 후 밀라노 베르디 국립음악원에서 오페라 전문 과정 수료. 벨칸토부터 현대 오페라까지 폭넓은 레퍼토리를 보유한 소프라노.",
         school="이화여자대학교 음악대학", course="bachelor", enroll=2014,
         school2="밀라노 베르디 국립음악원", course2="performance", enroll2=2018),
    dict(email="kang.taeyang@cadenza.app", pw=SEED_PASSWORD, name="강태양",
         major="지휘",   instrument="지휘",       cities=["서울","빈"],
         bio="서울대학교 음악대학 지휘과 졸업 후 빈 국립음악대학교(MDW)에서 지휘 박사 과정 수료. 현재 코리안심포니오케스트라 객원 지휘자로 활동하며 국내외 오케스트라와 꾸준히 협업 중.",
         school="서울대학교 음악대학", course="bachelor", enroll=2012,
         school2="빈 국립음악대학교", course2="phd", enroll2=2016),
    dict(email="yoon.sohee@cadenza.app",   pw=SEED_PASSWORD, name="윤소희",
         major="기악",   instrument="비올라",     cities=["서울","런던"],
         bio="한국예술종합학교 기악과 졸업 후 영국 로열 아카데미 오브 뮤직에서 석사 학위 취득. 솔리스트이자 실내악 연주자로서 보다 깊은 음색과 표현으로 비올라의 가능성을 탐구하고 있습니다.",
         school="한국예술종합학교", course="bachelor", enroll=2015,
         school2="로열 아카데미 오브 뮤직", course2="master", enroll2=2019),
    dict(email="im.jaewon@cadenza.app",    pw=SEED_PASSWORD, name="임재원",
         major="기악",   instrument="오보에",     cities=["서울","뮌헨"],
         bio="서울대학교 음악대학 기악과 졸업 후 뮌헨 국립음악대학(HMTM)에서 수학. 바이에른 방송 교향악단 협연 이후 유럽 오케스트라와의 협업을 이어가고 있는 오보에 연주자.",
         school="서울대학교 음악대학", course="bachelor", enroll=2014,
         school2="뮌헨 국립음악대학", course2="master", enroll2=2018),
    dict(email="han.jisu@cadenza.app",     pw=SEED_PASSWORD, name="한지수",
         major="피아노", instrument="피아노",     cities=["서울","뒤셀도르프"],
         bio="연세대학교 음악대학 피아노과를 수석으로 졸업하고 독일 로베르트 슈만 음대에서 최고연주자 과정 수료. 카네기홀 데뷔 이후 북미와 유럽을 오가며 활발한 연주 활동을 이어가고 있습니다.",
         school="연세대학교 음악대학", course="bachelor", enroll=2013,
         school2="로베르트 슈만 음대", course2="performance", enroll2=2017),
    dict(email="oh.hyunwoo@cadenza.app",   pw=SEED_PASSWORD, name="오현우",
         major="성악",   instrument="베이스바리톤", cities=["서울","베를린"],
         bio="서울대학교 음악대학 성악과 졸업 후 베를린 예술대학교(UdK Berlin)에서 가곡과 오라토리오 해석을 전문으로 수학. 슈베르트 가곡을 중심으로 독일 가곡의 깊이 있는 해석으로 주목받고 있습니다.",
         school="서울대학교 음악대학", course="bachelor", enroll=2013,
         school2="베를린 예술대학교", course2="master", enroll2=2017),
]

# ── 2. 이미지 다운로드 및 업로드 ──────────────────────────────────────────────

# picsum.photos 고정 ID (음악/공연 분위기와 어울리는 시드)
IMAGE_SEEDS = [
    10, 20, 30, 40, 50, 60, 70, 80, 90, 100,
    110, 120, 130, 140, 150, 160, 170, 180, 190, 200
]

def download_image(seed):
    url = f"https://picsum.photos/seed/{seed}/1200/800"
    r = requests.get(url, timeout=15)
    return r.content if r.ok else None

print("=== Cadenza Seed Script ===\n")

# ── 3. 계정 생성 ───────────────────────────────────────────────────────────────

print("▶ 1단계: 계정 생성")
user_ids = {}
for u in USERS:
    r = admin("POST", "users", json={
        "email": u["email"],
        "password": u["pw"],
        "email_confirm": True,
        "user_metadata": {"real_name": u["name"]}
    })
    if r.ok:
        uid = r.json()["id"]
        user_ids[u["email"]] = uid
        print(f"  ✓ {u['name']} ({uid[:8]}…)")
    else:
        # 이미 존재하면 목록에서 찾기
        lr = admin("GET", f"users?email={u['email']}")
        if lr.ok:
            users_list = lr.json().get("users", [])
            match = next((x for x in users_list if x["email"] == u["email"]), None)
            if match:
                uid = match["id"]
                user_ids[u["email"]] = uid
                print(f"  ~ {u['name']} 기존 계정 사용 ({uid[:8]}…)")
    time.sleep(0.3)

# ── 4. 프로필 업데이트 ─────────────────────────────────────────────────────────

print("\n▶ 2단계: 프로필 업데이트")
for u in USERS:
    uid = user_ids.get(u["email"])
    if not uid:
        continue
    r = rest("PATCH", f"profiles?id=eq.{uid}", json={
        "major": u["major"],
        "instrument": u["instrument"],
        "home_cities": u["cities"],
        "bio": u["bio"],
        "default_visibility": "public",
        "onboarding_complete": True,
    })
    print(f"  ✓ {u['name']} 프로필")

    # 학력 1
    rest("POST", "affiliations", json={
        "user_id": uid,
        "institution_name": u["school"],
        "course_type": u["course"],
        "enrollment_year": u["enroll"],
        "is_current": False,
    })
    # 학력 2 (대학원)
    rest("POST", "affiliations", json={
        "user_id": uid,
        "institution_name": u["school2"],
        "course_type": u["course2"],
        "enrollment_year": u["enroll2"],
        "is_current": True,
    })
    time.sleep(0.2)

# ── 5. 이미지 업로드 ───────────────────────────────────────────────────────────

print("\n▶ 3단계: 이미지 다운로드 및 업로드")
uploaded = {}   # seed → storage path
for i, seed in enumerate(IMAGE_SEEDS):
    img_data = download_image(seed)
    if not img_data:
        print(f"  !! 이미지 seed {seed} 다운로드 실패")
        continue
    path = f"seed/{seed}.jpg"
    ok = storage_upload("activity-images", path, img_data)
    if ok:
        uploaded[seed] = path
        print(f"  ✓ picsum seed {seed} → activity-images/{path}")
    time.sleep(0.3)

def img(seeds):
    return [uploaded[s] for s in seeds if s in uploaded]

# ── 6. 연결 (follows) ──────────────────────────────────────────────────────────

print("\n▶ 4단계: 사용자 간 연결 생성")
emails = list(user_ids.keys())
pairs = [
    (0,1),(0,2),(0,5),(1,2),(1,8),(2,3),(2,6),(3,4),(3,7),
    (4,5),(4,9),(5,6),(5,7),(6,8),(7,8),(8,9),(9,0),(1,5),(3,8),(6,9),
]
for a, b in pairs:
    if a >= len(emails) or b >= len(emails):
        continue
    uid_a = user_ids[emails[a]]
    uid_b = user_ids[emails[b]]
    rest("POST", "follows", json={
        "follower_id": uid_a, "followee_id": uid_b, "status": "accepted"
    })
    rest("POST", "follows", json={
        "follower_id": uid_b, "followee_id": uid_a, "status": "accepted"
    })
print(f"  ✓ {len(pairs)}쌍 양방향 연결")

# ── 7. 활동 게시물 ─────────────────────────────────────────────────────────────

def uid(email): return user_ids.get(email)

ACTIVITIES = [

  # ━━━━ 연주 (Performance) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  dict(user="kim.dohyun@cadenza.app", type="performance",
       title="서울시립교향악단 협연 — 브람스 바이올린 협주곡",
       date="2025-11-08", location="예술의전당 콘서트홀, 서울",
       role="협연 바이올리니스트", organizer="서울시립교향악단",
       program="J. Brahms — Violin Concerto in D major, Op. 77\nL. van Beethoven — Symphony No. 5 in C minor, Op. 67",
       description="""지난 11월, 예술의전당 콘서트홀에서 오스모 벤스케 지휘의 서울시립교향악단과 브람스 바이올린 협주곡을 협연했습니다.

브람스 협주곡은 제가 처음 바이올린을 시작했을 때부터 언젠가는 반드시 무대에서 연주하고 싶었던 곡입니다. 특히 1악장 카덴차에서는 거의 숨이 멎을 것 같은 집중감으로 임했고, 2,400석을 가득 메운 청중이 주는 에너지가 연주 내내 저를 지탱해주었습니다.

오케스트라의 따뜻하고 단단한 앙상블 덕분에 3악장 피날레에서는 제가 원하던 축제적인 에너지를 온전히 표현할 수 있었습니다. 함께해주신 서울시향 단원 여러분과 이 무대를 준비하면서 옆에서 응원해준 모든 분들께 진심으로 감사드립니다. 이 경험이 앞으로 제 음악 여정에 큰 자산이 될 것입니다.""",
       images=img([10, 20]), visibility="public"),

  dict(user="lee.seoyeon@cadenza.app", type="performance",
       title="금호아트홀 리사이틀 — 쇼팽과 드뷔시",
       date="2025-10-22", location="금호아트홀 연세, 서울",
       role="피아니스트", organizer="금호문화재단",
       program="F. Chopin — Ballade No.1 in G minor, Op. 23\nF. Chopin — Nocturnes Op. 27\nC. Debussy — Préludes Book I (complete)",
       description="""금호아트홀 연세에서 쇼팽과 드뷔시를 중심으로 한 피아노 독주회를 마쳤습니다.

파리에서 4년간 수학하며 제 안에서 자연스럽게 쌓인 프랑스적 음악 언어를 이번 리사이틀에서 처음으로 국내 관객들 앞에서 온전히 펼쳐 보이고 싶었습니다. 쇼팽의 발라드 1번은 서사적인 긴장감을, 드뷔시의 프렐류드 전곡은 빛과 색채의 변화를 극대화하는 방향으로 해석했습니다.

공연 후 많은 분들이 "드뷔시가 이렇게 생동감 있게 들린 건 처음"이라고 말씀해주셔서 정말 큰 힘이 됐습니다. 앞으로도 이 프로그램을 유럽 투어로 이어갈 예정이며, 다음 달 파리 살레 코르토에서의 공연을 기대해주세요.""",
       images=img([30, 40]), visibility="public"),

  dict(user="park.junseo@cadenza.app", type="performance",
       title="예술의전당 IBK챔버홀 독주회 — 바흐 무반주 첼로",
       date="2025-09-15", location="예술의전당 IBK챔버홀, 서울",
       role="첼리스트",
       program="J. S. Bach — Cello Suite No.1 in G major, BWV 1007\nJ. S. Bach — Cello Suite No.3 in C major, BWV 1009\nJ. S. Bach — Cello Suite No.5 in C minor, BWV 1011",
       description="""바흐의 무반주 첼로 모음곡 세 곡을 하룻밤 무대에 올렸습니다. 약 2시간 30분의 마라톤 연주였지만, 오히려 진행할수록 음악이 더 명료해지는 느낌이 들었습니다.

줄리아드에서의 5년 동안 저는 이 곡들을 하나의 전집으로 대하는 법을 배웠습니다. 각 모음곡이 독립적인 우주이면서도, 전체를 통해 바흐가 그려내는 더 큰 질서가 있다고 생각합니다. 이번 독주회는 그 질서를 처음으로 한국 청중과 나눠보고 싶다는 오랜 소망에서 비롯됐습니다.

공연 후 한 어르신이 제 손을 잡고 "처음으로 바흐가 외롭지 않게 들렸다"고 하셨을 때, 모든 연습의 의미가 집약되는 느낌이었습니다. 전곡 녹음도 연내 발매 예정이오니 많은 기대 부탁드립니다.""",
       images=img([50, 60]), visibility="public"),

  dict(user="choi.mina@cadenza.app", type="performance",
       title="서울필하모닉 협연 — 모차르트 플루트 협주곡 2번",
       date="2025-08-30", location="롯데콘서트홀, 서울",
       role="협연 플루티스트", organizer="서울필하모닉오케스트라",
       program="W. A. Mozart — Flute Concerto No.2 in D major, K.314\nA. Dvořák — Symphony No.9 in E minor, Op. 95 'New World'",
       description="""롯데콘서트홀에서 서울필하모닉오케스트라와 모차르트 플루트 협주곡 2번을 협연했습니다.

모차르트 협주곡은 악보가 단순해 보일수록 더 어렵다는 사실을 이번 협연을 통해 다시 한번 깨달았습니다. 모든 음표가 선명하게 드러나는 만큼, 음색 하나하나의 밀도와 숨의 흐름이 고스란히 청중에게 전달됩니다.

특히 2악장 안단테에서는 오케스트라의 현악 파트와 호흡이 완벽하게 맞아떨어지는 순간이 있었는데, 그 때 홀 전체가 숨을 죽이는 것이 느껴졌습니다. 오케스트라 단원분들과 협연을 허락해주신 서울필하모닉에 진심으로 감사드립니다.""",
       images=img([70, 80]), visibility="public"),

  dict(user="jung.haeun@cadenza.app", type="performance",
       title="국립오페라단 <라 보엠> — 미미 역",
       date="2025-07-12", location="예술의전당 오페라극장, 서울",
       role="소프라노 (미미)", organizer="국립오페라단",
       program="G. Puccini — La Bohème (전막)\n지휘: 파비오 루이시 / 연출: 로베르트 카르센",
       description="""국립오페라단의 새 시즌 오프닝 프로덕션, 푸치니의 라 보엠에서 미미 역을 맡아 총 4회 공연을 마쳤습니다.

국립오페라단 정규 시즌 무대에 서는 것은 이번이 처음입니다. 파비오 루이시 지휘 아래 로돌포 역의 테너 루카 살시와 함께 무대를 만들어가는 과정이 정말 값진 경험이었습니다. 특히 1막의 이중창 "O soave fanciulla"는 수십 번 연습했지만 실제 무대에서 조명이 켜지는 순간 느껴지는 전율은 언제나 새롭습니다.

밀라노에서 오페라를 공부할 때 꿈꾸던 무대에 드디어 섰습니다. 응원해주신 모든 분들과 이 기쁨을 나누고 싶습니다. 내년에는 베르디의 <라 트라비아타> 비올레타 역으로 돌아올 예정입니다.""",
       images=img([90, 100]), visibility="public"),

  dict(user="kang.taeyang@cadenza.app", type="performance",
       title="코리안심포니오케스트라 객원지휘 — 말러 교향곡 9번",
       date="2025-06-20", location="예술의전당 콘서트홀, 서울",
       role="객원 지휘자", organizer="코리안심포니오케스트라",
       program="G. Mahler — Symphony No.9 in D major",
       description="""코리안심포니오케스트라와 말러 교향곡 9번 전곡 공연을 마쳤습니다.

말러 9번은 지휘자에게 가장 도전적인 레퍼토리 중 하나입니다. 80분에 달하는 연주 내내 긴장을 유지하면서도 각 악장 고유의 서사를 청중에게 온전히 전달해야 합니다. 특히 마지막 악장 아다지오는 소리가 점점 소멸해가는 과정 자체가 음악이 되어야 한다는 점에서, 어떤 의미에서는 지휘자가 침묵을 지휘하는 경험입니다.

코리안심포니 단원들은 제가 요청하는 뉘앙스를 정확히 이해하고 표현해주었습니다. 특히 현악 파트의 집중력이 인상적이었으며, 4악장 코다에서 마지막 음이 사라진 후 약 10초간 이어진 정적은 제 지휘 인생에서 가장 아름다운 순간 중 하나로 기억될 것입니다.""",
       images=img([110, 120]), visibility="public"),

  dict(user="yoon.sohee@cadenza.app", type="performance",
       title="유리 바슈메트 앙상블과 협연 — 바르톡 비올라 협주곡",
       date="2025-05-18", location="Barbican Centre, 런던",
       role="협연 비올리스트", organizer="Barbican Centre / Bashmet Ensemble",
       program="B. Bartók — Viola Concerto, Sz. 120 (ed. Serly)\nD. Shostakovich — Chamber Symphony in C minor, Op. 110a",
       description="""런던 바비칸 센터에서 유리 바슈메트가 이끄는 모스크바 솔로이스츠 앙상블과 바르톡 비올라 협주곡을 협연했습니다.

바르톡의 비올라 협주곡은 그의 유작으로, 악보가 완성되지 않은 채 남겨졌기에 해석의 여지가 그 어떤 곡보다 넓습니다. 저는 쎌리 편곡본을 바탕으로 하되, 제가 상상하는 바르톡의 음악적 의도를 최대한 반영하는 카덴차 버전을 직접 수정해서 연주했습니다.

바슈메트 선생님은 리허설 내내 "비올라는 노래하는 악기"라는 말씀을 반복하셨습니다. 그 말이 공연 내내 제 귀에 울렸습니다. 런던의 청중들 앞에서 이 곡을 연주할 수 있어서 정말 영광이었고, 이 경험이 앞으로의 연주 방향에 큰 전환점이 될 것 같습니다.""",
       images=img([130, 140]), visibility="public"),

  dict(user="im.jaewon@cadenza.app", type="performance",
       title="바이에른 방송 교향악단 협연 — 모차르트 오보에 협주곡",
       date="2025-04-10", location="Herkulessaal, 뮌헨",
       role="협연 오보에 주자", organizer="Bayerischer Rundfunk",
       program="W. A. Mozart — Oboe Concerto in C major, K.314\nR. Strauss — Eine Alpensinfonie, Op. 64",
       description="""독일 뮌헨의 헤르쿨레스잘에서 바이에른 방송 교향악단과 모차르트 오보에 협주곡을 협연했습니다.

바이에른 방송 교향악단은 세계 정상급 앙상블로서, 이 무대에 서기까지 뮌헨에서 5년간의 유학 생활이 필요했습니다. 오보에는 화려함보다는 선율의 순수함으로 승부하는 악기입니다. 모차르트가 이 협주곡에서 요구하는 것은 기교적 완성도보다는 자연스러운 노래하는 능력—cantabile—입니다.

리허설에서 수석 지휘자 사이먼 래틀 경이 "당신의 오보에가 홀 전체를 채우고 있다"고 말씀해주셨을 때, 정말 그 순간을 위해 지금껏 연습해왔다는 생각이 들었습니다. 이 소중한 기회를 주신 BR Klassik과 함께해주신 단원 여러분께 감사드립니다.""",
       images=img([150, 160]), visibility="public"),

  dict(user="han.jisu@cadenza.app", type="performance",
       title="Carnegie Hall Weill Recital Hall 뉴욕 데뷔 리사이틀",
       date="2025-03-05", location="Weill Recital Hall, Carnegie Hall, 뉴욕",
       role="피아니스트",
       program="L. van Beethoven — Piano Sonata No.21 'Waldstein', Op.53\nF. Schubert — Wanderer-Fantasie in C major, D.760\nS. Rachmaninoff — Piano Sonata No.2 in B♭ minor, Op.36 (rev. 1931)",
       description="""지난 3월, 뉴욕 카네기홀 와일 리사이틀 홀에서 데뷔 리사이틀을 가졌습니다.

카네기홀이라는 이름 앞에서 처음에는 압도되는 느낌이 있었습니다. 하지만 무대에 올라 피아노 앞에 앉는 순간, 수십 년 동안 이 홀에서 연주했던 수많은 피아니스트들의 에너지가 건반에 담겨있다는 느낌을 받았습니다. 그 에너지가 저를 이끌어가는 공연이었습니다.

베토벤 발트슈타인 소나타로 시작해 슈베르트의 방랑자 환상곡을 거쳐 라흐마니노프 소나타 2번으로 마무리하는 프로그램은, 고전의 논리에서 출발해 낭만의 감성으로 폭발하는 서사를 담고자 했습니다. New York Times 클래식 섹션에 리뷰가 실린 것도 영광스러운 기억으로 남아 있습니다.""",
       images=img([170, 180]), visibility="public"),

  dict(user="oh.hyunwoo@cadenza.app", type="performance",
       title="슈베르트 겨울나그네 — 가곡 리사이틀",
       date="2025-02-14", location="세종체임버홀, 서울",
       role="베이스바리톤", organizer="세종문화회관",
       program="F. Schubert — Winterreise, D.911 (완창)\n피아노 반주: 김민재",
       description="""밸런타인데이에 슈베르트의 겨울나그네를 완창했습니다. 사랑의 날에 이별과 방랑의 노래를 부른다는 아이러니가 오히려 이 작품을 더욱 깊이 있게 만들어준다고 생각했습니다.

겨울나그네는 베이스바리톤 가수가 일생에 걸쳐 성숙시켜나가는 레퍼토리입니다. 24개의 곡으로 이루어진 이 연가곡은 단순한 기술이 아니라 삶의 경험과 언어에 대한 깊은 이해 없이는 접근할 수 없는 작품입니다. 베를린에서 3년간 독일 리트를 전문으로 공부한 것이 이번 무대에서 비로소 의미를 갖는 것 같았습니다.

피아니스트 김민재씨와의 두터운 신뢰가 있었기에 가능했던 공연입니다. 특히 15번 곡 '까마귀'에서 피아노와 성악이 만들어낸 어두운 색채는 공연 중 제가 가장 자랑스러웠던 순간이었습니다.""",
       images=img([190, 200]), visibility="public"),

  # ━━━━ 경연 (Competition) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  dict(user="kim.dohyun@cadenza.app", type="competition",
       title="퀸 엘리자베스 국제 바이올린 콩쿠르 — 입상",
       date="2024-06-01", location="Bozar, 브뤼셀, 벨기에",
       role="참가자 / 입상", organizer="Queen Elisabeth Competition",
       prize="준결선 진출 / 심사위원 특별상",
       program="지정곡: B. Bartók — Violin Concerto No.2\n자유곡: J. S. Bach — Partita No.2 in D minor, BWV 1004 / Y. Sibelius — Violin Concerto in D minor, Op.47",
       description="""세계 3대 콩쿠르 중 하나인 퀸 엘리자베스 국제 콩쿠르에 참가해 준결선에 진출하고 심사위원 특별상을 수상했습니다.

벨기에 브뤼셀에서 2주간 진행된 이 콩쿠르는 제 음악 인생에서 가장 강렬한 경험 중 하나였습니다. 1차 예선부터 준결선까지 총 6회의 무대를 소화하면서, 경쟁보다는 제 음악을 가장 진실되게 표현하는 것에 집중하려 했습니다.

특히 준결선에서 바르톡 협주곡 2번을 연주할 때, 오케스트라와의 첫 합주에서 나오는 소리가 생각했던 것보다 훨씬 크고 강렬해서 잠시 압도됐습니다. 하지만 그 압도감을 오히려 에너지로 전환해 연주했고, 연주 후 청중의 반응이 뜨거웠습니다. 결선 진출에는 아쉽게 실패했지만, 이 경험을 통해 국제 무대에서 경쟁하는 자신감을 얻었습니다.""",
       images=img([20, 50]), visibility="public"),

  dict(user="lee.seoyeon@cadenza.app", type="competition",
       title="쇼팽 국제 피아노 콩쿠르 — 파이널리스트",
       date="2024-10-20", location="바르샤바 필하모닉홀, 폴란드",
       role="파이널리스트", organizer="Chopin Institute",
       prize="파이널리스트 (6위권 진입)",
       program="지정곡: F. Chopin — Piano Sonata No.2 in B♭ minor, Op.35\n자유곡: F. Chopin — Ballades (전곡), Études Op.10 선곡\n협주곡: F. Chopin — Piano Concerto No.1 in E minor, Op.11",
       description="""5년에 한 번 열리는 쇼팽 국제 피아노 콩쿠르에서 파이널리스트로 선정되었습니다.

바르샤바에서 3주간 진행된 이 콩쿠르는 파리에서 쇼팽을 중심으로 공부해온 저에게 가장 의미 있는 도전이었습니다. 1차부터 3차 예선까지 쇼팽의 음악 세계를 단계적으로 심화시켜가는 과정 자체가 하나의 음악적 여정이었습니다.

결선에서 쇼팽 피아노 협주곡 1번을 바르샤바 필하모닉과 협연할 때는, 쇼팽의 고향 도시에서 그의 음악을 연주한다는 사실이 전율로 다가왔습니다. 최종 입상에는 아쉽게 실패했지만, 이번 콩쿠르를 통해 만난 음악가들과의 연결, 그리고 음악에 대한 더 깊은 이해를 얻었습니다. 이 경험은 앞으로 제 연주 인생의 중요한 기반이 될 것입니다.""",
       images=img([40, 80]), visibility="public"),

  dict(user="park.junseo@cadenza.app", type="competition",
       title="로스트로포비치 국제 첼로 콩쿠르 — 1위",
       date="2024-05-15", location="파리 필하모니, 프랑스",
       role="우승자", organizer="Fondation Rostropovich-Vishnevskaya",
       prize="1위 (Grand Prix)",
       program="지정곡: D. Shostakovich — Cello Concerto No.1\n자유곡: J. S. Bach — Cello Suite No.6 / E. Elgar — Cello Concerto",
       description="""파리 필하모니에서 개최된 제15회 로스트로포비치 국제 첼로 콩쿠르에서 1위를 수상했습니다.

로스트로포비치는 제가 첼로를 시작했을 때부터 가장 존경하는 첼리스트입니다. 그의 이름을 딴 콩쿠르에서 우승하게 되어 영광스럽고, 동시에 막중한 책임감을 느낍니다. 줄리아드에서 5년간의 수학이 이번 수상의 밑거름이 되었다고 생각합니다.

결선 무대에서 쇼스타코비치 첼로 협주곡 1번을 연주할 때, 작곡가가 이 곡을 통해 전달하고자 했던 시대적 고통과 저항의 의지를 내 음악으로 표현하는 데 모든 에너지를 집중했습니다. 심사위원단이 만장일치로 1위를 수여했다는 소식을 들었을 때, 옆에서 함께 울어준 줄리아드 동기들이 가장 먼저 떠올랐습니다.""",
       images=img([60, 100]), visibility="public"),

  dict(user="choi.mina@cadenza.app", type="competition",
       title="ARD 뮌헨 국제 음악 콩쿠르 — 플루트 부문 2위",
       date="2024-09-08", location="뮌헨 헤르쿨레스잘, 독일",
       role="입상자", organizer="ARD International Music Competition",
       prize="2위",
       program="지정곡: S. Prokofiev — Sonata for Flute and Piano, Op.94\n자유곡: C. P. E. Bach — Flute Concerto in D minor / T. Takemitsu — Voice",
       description="""세계 최고 권위의 음악 콩쿠르 중 하나인 ARD 뮌헨 국제 음악 콩쿠르 플루트 부문에서 2위를 수상했습니다.

ARD 콩쿠르는 단순한 기술의 경연이 아니라 음악적 상상력과 개성을 평가하는 자리라고 느꼈습니다. 저는 이번 콩쿠르에서 무조건 화려한 테크닉보다는, 플루트가 표현할 수 있는 색채의 다양함을 보여주는 데 집중했습니다. 특히 다케미쓰의 Voice는 현대음악에 대한 제 관심과 개성을 가장 잘 드러낼 수 있는 선택이었습니다.

인디애나 대학교에서 배운 다층적인 음악 해석 방법이 이번 무대에서 빛을 발했다고 생각합니다. 1위보다 2위가 더 어렵다는 말이 있는데, 그 말의 무게가 이번 수상을 통해 느껴집니다. 더 성장해서 돌아오겠습니다.""",
       images=img([70, 130]), visibility="public"),

  dict(user="jung.haeun@cadenza.app", type="competition",
       title="한스 가보어 벨베데레 성악 콩쿠르 — 오페라 부문 1위",
       date="2023-06-10", location="빈 국립오페라극장, 오스트리아",
       role="우승자", organizer="Hans Gabor Belvedere Singing Competition",
       prize="오페라 부문 1위",
       program="자유곡: G. Verdi — 'Caro nome' (리골레토)\nG. Puccini — 'Si, mi chiamano Mimì' (라 보엠)\n결선: G. Puccini — 'Vissi d'arte' (토스카)",
       description="""빈 국립오페라극장에서 개최된 한스 가보어 벨베데레 성악 콩쿠르 오페라 부문에서 1위를 수상했습니다.

밀라노 베르디 음악원에서의 3년 수학을 마치고 처음 도전한 국제 성악 콩쿠르에서의 수상이라 더욱 뜻깊습니다. 빈 국립오페라극장 무대에 서는 것 자체가 꿈이었는데, 그 무대에서 입상까지 하게 되어 아직도 실감이 나지 않습니다.

결선 무대에서 토스카의 비시 다르테를 부를 때, 빈의 청중들이 주는 에너지가 온몸을 감쌌습니다. 이탈리아에서 갈고 닦은 벨칸토 발성이 드디어 국제 무대에서 인정받은 것 같아 교수님께 제일 먼저 연락했습니다. 이 수상을 계기로 유럽 오페라 하우스와의 협업이 더욱 활발해질 것으로 기대합니다.""",
       images=img([90, 150]), visibility="public"),

  dict(user="han.jisu@cadenza.app", type="competition",
       title="클리블랜드 국제 피아노 콩쿠르 — 2위",
       date="2023-09-25", location="클리블랜드 세베란스홀, 미국",
       role="입상자", organizer="Cleveland International Piano Competition",
       prize="2위 (Silver Medal)",
       program="지정곡: S. Prokofiev — Piano Sonata No.7\n자유곡: F. Liszt — Sonata in B minor / S. Rachmaninoff — Piano Concerto No.3",
       description="""미국 클리블랜드에서 개최된 클리블랜드 국제 피아노 콩쿠르에서 2위(실버 메달)를 수상했습니다.

뒤셀도르프에서 로베르트 슈만 음대 최고연주자 과정을 마치고 첫 도전한 미국 콩쿠르였습니다. 프로코피예프 소나타 7번은 전쟁 시대의 폭력성과 내면의 혼돈을 극도의 기술적 요구와 함께 담아낸 곡으로, 제가 가장 좋아하는 20세기 소나타입니다.

결선에서 라흐마니노프 협주곡 3번을 클리블랜드 오케스트라와 협연하는 경험은 평생 잊지 못할 것입니다. 제프리 카한 음악감독의 완벽한 리드 덕분에 제가 원하는 음악적 표현에 집중할 수 있었습니다. 이 수상을 계기로 북미 투어 일정이 확정되어 올 가을 뉴욕, 보스턴, 시카고에서 순차적으로 리사이틀을 가질 예정입니다.""",
       images=img([170, 30]), visibility="public"),

  dict(user="yoon.sohee@cadenza.app", type="competition",
       title="리오넬 테르티스 국제 비올라 콩쿠르 — 3위",
       date="2023-10-05", location="맨 섬(Isle of Man), 영국",
       role="입상자", organizer="Lionel Tertis International Viola Competition",
       prize="3위 및 청중상",
       program="지정곡: W. Walton — Viola Concerto\n자유곡: B. Bartók — Viola Concerto / P. Hindemith — Der Schwanendreher",
       description="""영국 맨 섬에서 개최된 리오넬 테르티스 국제 비올라 콩쿠르에서 3위와 청중상을 동시에 수상했습니다.

테르티스는 비올라를 독주 악기로 끌어올린 전설적인 비올리스트입니다. 그의 이름을 딴 콩쿠르에 도전하면서, 비올라의 가능성을 확장하는 연주자가 되겠다는 제 음악적 신념을 더욱 굳건히 하게 됐습니다.

월튼 협주곡은 영국 낭만주의의 정수라 할 수 있는 곡으로, 영국 작곡가의 음악을 영국 청중 앞에서 연주하는 특별한 의미가 있었습니다. 특히 청중상까지 함께 수상한 것이 기쁩니다. 기술적 완성도보다 청중과의 소통을 중시하는 제 연주 철학이 통했다고 생각합니다.""",
       images=img([140, 20]), visibility="public"),

  dict(user="oh.hyunwoo@cadenza.app", type="competition",
       title="ARD 국제 음악 콩쿠르 — 성악(리트) 부문 입상",
       date="2023-09-12", location="뮌헨 헤르쿨레스잘, 독일",
       role="입상자", organizer="ARD International Music Competition",
       prize="3위 및 특별상 (최고 리트 해석상)",
       program="자유곡: F. Schubert — Winterreise D.911 (선곡)\nR. Schumann — Dichterliebe Op.48 (전곡)\n결선: H. Wolf — Mörike-Lieder 선곡",
       description="""ARD 국제 음악 콩쿠르 성악(리트) 부문에서 3위와 최고 리트 해석 특별상을 수상했습니다.

독일 예술가곡, 즉 리트는 텍스트와 음악이 하나가 되어야 하는 장르로, 언어에 대한 깊은 이해 없이는 접근할 수 없습니다. 베를린 예술대학교에서 리트를 전공으로 공부한 것이 이번 수상의 핵심이었다고 생각합니다.

심사위원단이 "텍스트에 대한 이해와 음악적 표현이 완벽하게 일치한다"고 평가해주셨는데, 그것이 제가 가장 집중했던 부분이었기에 더욱 의미 있었습니다. 특히 최고 리트 해석 특별상은 제가 지향하는 음악적 방향이 인정받은 것 같아 가장 기쁜 수상이었습니다.""",
       images=img([190, 60]), visibility="public"),

  # ━━━━ 교육 (Education) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  dict(user="kim.dohyun@cadenza.app", type="education",
       title="자하르 브론 마스터클래스 — 쾰른 음대",
       date="2024-08-20", location="쾰른 음악대학, 독일",
       role="수강생",
       program="J. Brahms — Violin Sonata No.1 in G major, Op.78\nY. Sibelius — Violin Concerto in D minor, Op.47 (1악장)",
       description="""세계 최고의 바이올린 교수 중 한 명인 자하르 브론 교수의 마스터클래스에 참가했습니다.

브론 교수는 막심 벤게로프, 사라 장 등 수많은 바이올리니스트를 배출한 전설적인 교수입니다. 쾰른 음대에서 3일간 진행된 이번 마스터클래스에서 저는 브람스 소나타와 시벨리우스 협주곡을 레슨 받았습니다.

브론 교수가 제 연주에 가장 많이 언급하신 것은 "오른팔의 무게를 활에 실어라"는 것이었습니다. 기술적으로는 알고 있었지만 실제 연주에서 무의식적으로 팔에 힘을 주는 습관이 있었는데, 교수님의 즉각적인 피드백 덕분에 그 순간 바로 소리가 달라지는 것을 경험했습니다. 5시간의 레슨이 지금껏 5년의 연습보다 더 많은 것을 배운 시간이었습니다.""",
       images=img([10, 70]), visibility="public"),

  dict(user="lee.seoyeon@cadenza.app", type="education",
       title="알프레드 브렌델 피아노 세미나 — 잘츠부르크",
       date="2024-07-15", location="모차르테움, 잘츠부르크, 오스트리아",
       role="수강생",
       program="L. van Beethoven — Piano Sonata Op.109\nF. Schubert — Piano Sonata in B♭ major, D.960",
       description="""잘츠부르크 모차르테움에서 전설적인 피아니스트 알프레드 브렌델의 피아노 세미나에 참가했습니다.

브렌델은 베토벤과 슈베르트 해석의 대가로서 평생 이론과 연주를 병행해온 음악가입니다. 현재는 연주를 은퇴하고 교육에 전념하고 있어, 이번 세미나는 그의 깊이 있는 통찰을 직접 들을 수 있는 귀한 기회였습니다.

브렌델은 제 슈베르트 소나타 D.960 연주에 대해 "슈베르트의 침묵을 두려워하지 말라. 그 침묵이 음악이다"라는 말씀을 하셨습니다. 페르마타와 쉼표를 단순한 정지가 아니라 음악적 긴장을 유지하는 공간으로 대하는 방식이 제 슈베르트 해석을 완전히 바꿔놓았습니다. 이 세미나 덕분에 이번 시즌 프로그램에 슈베르트 소나타를 메인 레퍼토리로 추가했습니다.""",
       images=img([40, 110]), visibility="public"),

  dict(user="kang.taeyang@cadenza.app", type="education",
       title="정명훈 마스터클래스 — 서울대학교 음악대학",
       date="2024-06-05", location="서울대학교 음악대학, 서울",
       role="수강생",
       program="G. Mahler — Symphony No.5 in C♯ minor (1, 2악장)\nL. van Beethoven — Symphony No.7 in A major, Op.92 (3, 4악장)",
       description="""서울대학교 음악대학에서 정명훈 지휘자의 마스터클래스에 참가했습니다.

정명훈 선생님은 저에게 지휘를 처음 배우게 한 음악가입니다. 어린 시절 그분의 베를린 필 영상을 보고 지휘의 길을 선택했기에, 직접 레슨을 받는 이 경험은 말로 형용할 수 없는 감격이었습니다.

말러 5번 1악장을 지휘하면서 선생님이 멈추고 말씀하신 것은 예상 밖의 것이었습니다. "너는 지금 오케스트라에게 지시하고 있다. 지시가 아니라 제안하라." 지휘는 권위가 아니라 대화라는 것, 단원들이 먼저 음악을 느끼도록 공간을 주어야 한다는 것을 그 순간 온몸으로 이해했습니다. 빈에서 박사 공부를 마치고 돌아와 이 가르침을 받을 수 있어서 더욱 의미가 깊습니다.""",
       images=img([120, 180]), visibility="public"),

  dict(user="im.jaewon@cadenza.app", type="education",
       title="하인츠 홀리거 오보에 마스터클래스 — 바젤 음악대학",
       date="2024-05-10", location="바젤 음악대학, 스위스",
       role="수강생",
       program="W. A. Mozart — Oboe Quartet in F major, K.370\nB. Britten — Six Metamorphoses after Ovid, Op.49",
       description="""바젤 음악대학에서 현존하는 최고의 오보이스트 중 한 명인 하인츠 홀리거의 마스터클래스에 참가했습니다.

홀리거는 연주자인 동시에 작곡가로서, 오보에의 기술적 경계를 수십 년간 확장해온 음악가입니다. 브리튼의 6개의 변신을 레슨 받으면서, 각 신화적 인물이 가진 고통과 변용의 과정을 어떻게 음색으로 표현할 것인지에 대한 심층적인 이야기를 들었습니다.

홀리거는 "오보에는 기계적으로 아름다운 소리를 내는 악기가 아니다. 불완전하고 거친 소리 안에서 오히려 인간적인 표현이 가능하다"고 하셨습니다. 완벽한 인토네이션에만 집중해온 제 연습 방식을 다시 생각하게 된 전환점이 된 레슨이었습니다. 뮌헨에서 5년을 공부했지만, 이 3일이 가장 많이 바꿔준 시간이었습니다.""",
       images=img([160, 40]), visibility="public"),

  dict(user="han.jisu@cadenza.app", type="education",
       title="크리스토프 에셴바흐 피아노 마스터클래스 — 파리",
       date="2024-03-20", location="파리 고등음악원(CNSMDP), 프랑스",
       role="수강생",
       program="S. Rachmaninoff — Piano Concerto No.3 in D minor, Op.30\nL. van Beethoven — Piano Sonata No.29 'Hammerklavier', Op.106",
       description="""파리 고등음악원에서 지휘자이자 피아니스트인 크리스토프 에셴바흐의 마스터클래스에 참가했습니다.

에셴바흐는 피아니스트와 지휘자 모두로서 세계 정상의 경력을 지닌 음악가입니다. 이번 마스터클래스에서는 라흐마니노프 협주곡 3번을 중심으로 오케스트라와의 협연에서 솔리스트가 가져야 할 음악적 리더십에 대한 깊은 통찰을 얻었습니다.

특히 라흐마니노프 3번 2악장 카덴차 부분에서 에셴바흐가 직접 두 번째 피아노로 오케스트라 파트를 연주하며 레슨해주신 부분이 압도적이었습니다. 솔리스트와 오케스트라가 어떻게 대화해야 하는지를 몸으로 느낀 경험이었습니다. 다음 달 카네기홀 독주회의 프로그램을 이 마스터클래스 이후 전면 재구성했습니다.""",
       images=img([180, 90]), visibility="public"),

  dict(user="park.junseo@cadenza.app", type="education",
       title="미샤 마이스키 첼로 마스터클래스 — 베네치아",
       date="2023-08-25", location="베네치아 페니체 극장, 이탈리아",
       role="수강생",
       program="L. van Beethoven — Cello Sonata No.3 in A major, Op.69\nD. Shostakovich — Cello Sonata in D minor, Op.40",
       description="""이탈리아 베네치아 페니체 극장에서 미샤 마이스키의 첼로 마스터클래스에 참가했습니다.

미샤 마이스키는 로스트로포비치의 직계 제자로서, 그 음악적 혈통을 이어받은 첼리스트입니다. 베네치아의 역사적인 오페라 극장에서 레슨을 받는다는 것 자체가 비현실적인 경험이었습니다.

마이스키는 베토벤 소나타 69번의 첫 소절을 제가 연주하자마자 멈추고 이렇게 말했습니다. "이 음표들은 어디에서 오는 것인가? 음표 이전의 고요함에서 시작해야 한다." 음악은 첫 음이 아니라 그 이전의 침묵에서부터 이미 시작된다는 것—줄리아드에서 배운 기술적 완성도 너머의 철학을 이 레슨에서 처음으로 이해했습니다. 로스트로포비치 콩쿠르 우승 이후에도 배움의 자세를 잃지 않겠다는 다짐을 새롭게 했습니다.""",
       images=img([60, 150]), visibility="public"),

  # ━━━━ 음반/미디어 (Recording) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  dict(user="kim.dohyun@cadenza.app", type="recording",
       title="데뷔 앨범 발매 — 《Resonance》 (Naxos Records)",
       date="2025-01-20", location="Teldex Studio Berlin, 베를린",
       role="바이올리니스트",
       program="C. Franck — Violin Sonata in A major\nJ. Brahms — Violin Sonata No.3 in D minor, Op.108\nC. Saint-Saëns — Introduction et Rondo Capriccioso",
       description="""드디어 첫 솔로 앨범 《Resonance》가 Naxos Records를 통해 전 세계에 발매되었습니다.

베를린 텔덱스 스튜디오에서 사흘 동안 진행된 녹음 작업은 제 음악 인생에서 가장 집중적이고 도전적인 경험이었습니다. 무대 연주와 달리 녹음은 모든 음표가 영구적으로 기록된다는 사실이 좋은 의미에서 부담이 되었고, 그 부담이 오히려 더 깊은 표현을 끌어냈습니다.

앨범의 메인 레퍼토리인 프랑크 바이올린 소나타는 완성도 높은 낭만주의 실내악의 걸작으로, 피아니스트 다니엘 지아코멜리와의 완벽한 호흡이 없었다면 이 녹음은 불가능했을 것입니다. Gramophone, BBC Music Magazine 등 유럽 주요 매체의 리뷰가 예정되어 있으며, 스포티파이와 애플뮤직에서도 오늘부터 감상하실 수 있습니다.""",
       images=img([10, 110]), visibility="public"),

  dict(user="lee.seoyeon@cadenza.app", type="recording",
       title="《Impressions》 — 드뷔시 & 라벨 (Deutsche Grammophon)",
       date="2024-12-10", location="Studio La Seine, 파리",
       role="피아니스트",
       program="C. Debussy — Préludes Book I & Book II (complete)\nM. Ravel — Gaspard de la nuit\nM. Ravel — Miroirs",
       description="""Deutsche Grammophon 레이블을 통해 드뷔시와 라벨 피아노 작품집 《Impressions》를 발매했습니다.

DG와의 레코딩 계약은 파리 유학 시절부터 가장 간절히 원했던 꿈이었습니다. 파리의 Studio La Seine은 음향적으로 완벽한 환경을 제공하며, 4일간의 녹음 세션 동안 프로듀서 마르쿠스 라이너와 긴밀히 작업하며 최적의 음향을 찾았습니다.

드뷔시 프렐류드 전곡을 한 앨범에 담는 것은 각 곡의 색채와 분위기가 서로 대조를 이루면서도 하나의 흐름을 만들어야 하는 도전적인 과제였습니다. 라벨의 가스파르 드 라 뉘는 제가 지금껏 연습한 레퍼토리 중 가장 어려운 곡이지만, 그만큼 표현의 폭이 넓은 작품입니다. 이 앨범이 드뷔시와 라벨의 인상주의 음악을 새롭게 경험하는 계기가 되길 바랍니다.""",
       images=img([30, 130]), visibility="public"),

  dict(user="jung.haeun@cadenza.app", type="recording",
       title="오페라 아리아 앨범 《Una voce》 (Sony Classical)",
       date="2024-11-05", location="Abbey Road Studios, 런던",
       role="소프라노",
       program="G. Donizetti — 'Una furtiva lagrima' (사랑의 묘약)\nG. Verdi — 'Caro nome' (리골레토)\nG. Puccini — 'O mio babbino caro' (잔니 스키키)\nW. A. Mozart — 'Voi che sapete' (피가로의 결혼) 외 12곡",
       description="""런던 애비 로드 스튜디오에서 녹음한 오페라 아리아 앨범 《Una voce》가 Sony Classical을 통해 발매되었습니다.

비틀즈가 녹음했던 그 스튜디오에서 제 목소리를 담았습니다. 녹음 첫날 스튜디오에 들어서며 느낀 감정은 설레임과 경외감이 동시에 밀려오는 느낌이었습니다. 벨베데레 콩쿠르 우승 이후 여러 레이블에서 연락이 왔지만, Sony Classical의 프로듀서 디노 니체베르가 저의 음악적 방향성을 가장 잘 이해해준다는 느낌에 계약을 결정했습니다.

총 16개의 아리아를 수록한 이 앨범은 벨칸토부터 베리즈모까지 제 성악적 레퍼토리의 다양성을 보여주는 것을 목표로 했습니다. 지휘는 이탈리아의 파비오 비온디가 맡아주었고, 오케스트라는 유럽 챔버 오케스트라가 함께했습니다.""",
       images=img([90, 170]), visibility="public"),

  dict(user="kang.taeyang@cadenza.app", type="recording",
       title="코리안심포니오케스트라 라이브 앨범 — 브람스 교향곡 전집",
       date="2024-09-30", location="예술의전당 콘서트홀, 서울",
       role="지휘자", organizer="코리안심포니오케스트라",
       program="J. Brahms — Symphony No.1-4 (전곡)\n라이브 레코딩 (2023-2024 시즌 연속 공연)",
       description="""코리안심포니오케스트라와 함께한 브람스 교향곡 전집 프로젝트의 라이브 앨범이 Decca Classics를 통해 발매됩니다.

2023년부터 2024년에 걸쳐 4회의 연속 공연으로 진행된 이 프로젝트는 제가 코리안심포니와 함께한 가장 야심찬 시도였습니다. 브람스의 4개의 교향곡은 베토벤의 유산을 계승하면서도 완전히 독자적인 음악 세계를 구축한, 교향곡 장르의 정점이라 할 수 있습니다.

라이브 레코딩의 특성상 스튜디오 녹음과 달리 즉흥성과 현장감이 그대로 담겼습니다. 특히 4번 교향곡 4악장 파사칼리아에서 32개의 변주가 하나의 거대한 흐름으로 이어지는 과정—그것이 이 앨범에서 제가 청중에게 들려드리고 싶었던 가장 중요한 순간입니다. 모든 공연을 통해 성장해온 코리안심포니 단원들에게 깊은 감사를 드립니다.""",
       images=img([120, 50]), visibility="public"),

  dict(user="park.junseo@cadenza.app", type="recording",
       title="바흐 무반주 첼로 모음곡 전집 (ECM Records)",
       date="2024-08-15", location="Propstei St. Gerold, 오스트리아",
       role="첼리스트",
       program="J. S. Bach — Six Cello Suites, BWV 1007-1012 (전곡)\n2CD 세트",
       description="""ECM Records를 통해 바흐 무반주 첼로 모음곡 전집을 발매했습니다. 오스트리아 알프스 산중의 수도원 게롤트 성당에서 녹음한 것으로, 그 공간의 자연적인 음향이 그대로 담겨 있습니다.

ECM의 프로듀서 만프레드 아이허는 음반 녹음을 단순한 음악 기록이 아닌 하나의 음향적 예술 작품으로 접근합니다. 성당의 돌벽에서 나오는 약 3초의 잔향이 바흐의 대위법적 선율에 특별한 입체감을 더해주었습니다.

6개의 모음곡을 전집으로 녹음하는 것은 제가 5년 전부터 준비해온 프로젝트입니다. 로스트로포비치 콩쿠르 우승 후 여러 레이블의 제안이 있었지만, ECM의 음향 미학과 제 음악적 방향이 가장 잘 맞는다는 확신으로 이 레이블을 선택했습니다. Gramophone 에디터스 초이스 선정을 기대하고 있으며, 이미 BBC Radio 3에서 전곡 방송 예정이 확정됐습니다.""",
       images=img([60, 200]), visibility="public"),

  dict(user="choi.mina@cadenza.app", type="recording",
       title="현대 플루트 음악 앨범 《Breath》 (BIS Records)",
       date="2024-06-25", location="Järvenpää Hall, 핀란드",
       role="플루티스트",
       program="T. Takemitsu — Voice for solo flute\nL. Berio — Sequenza I for solo flute\nP. Boulez — Sonatine for flute and piano\nS. Gubaidulina — Sonata for flute and piano",
       description="""스웨덴 BIS Records를 통해 현대 음악 플루트 앨범 《Breath》를 발매했습니다. 핀란드 예르벤패 홀에서의 녹음으로, BIS의 SACD 포맷을 통해 플루트의 섬세한 음색이 완벽하게 재현되었습니다.

현대 음악을 전문으로 하는 앨범을 첫 번째 솔로 디스크로 내는 것이 의아하게 보일 수 있습니다. 하지만 저는 플루트가 낭만주의 시대보다 오히려 현대 음악에서 더 넓은 가능성을 갖는 악기라고 확신합니다. 다케미쓰의 Voice는 단순한 플루트 독주곡이 아니라 호흡 자체를 음악으로 만드는 작품입니다.

인디애나 대학교에서 현대음악 앙상블 활동을 통해 쌓은 경험이 이 앨범의 토대가 되었습니다. ARD 콩쿠르에서 다케미쓰를 자유곡으로 선택한 것도, 이 앨범을 준비하는 여정의 일부였습니다. 클래식 음악의 경계를 확장하는 플루티스트로 계속 성장해나가겠습니다.""",
       images=img([80, 190]), visibility="public"),
]

print(f"\n▶ 5단계: 활동 게시물 생성 ({len(ACTIVITIES)}개)")
for i, a in enumerate(ACTIVITIES):
    uid_a = uid(a["user"])
    if not uid_a:
        print(f"  !! 사용자 없음: {a['user']}")
        continue
    payload = {
        "user_id": uid_a,
        "type": a["type"],
        "title": a["title"],
        "activity_date": a["date"],
        "location": a.get("location"),
        "role": a.get("role"),
        "visibility": a.get("visibility", "public"),
        "program": a.get("program"),
        "organizer": a.get("organizer"),
        "prize": a.get("prize"),
        "image_urls": a.get("images", []),
        "personal_note": a["description"],
    }
    r = rest("POST", "activities", json=payload)
    status = "✓" if r.ok else "!!"
    print(f"  {status} [{a['type'][:3].upper()}] {a['title'][:40]}")
    time.sleep(0.25)

print("\n✅ 시드 완료!")
print(f"   계정 {len(user_ids)}개, 게시물 {len(ACTIVITIES)}개 생성")
print(f"   이미지 {len(uploaded)}개 업로드")
print("\n테스트 계정 (모두 비밀번호: Cadenza123!)")
for u in USERS:
    print(f"   {u['name']:6s}  {u['email']}")
