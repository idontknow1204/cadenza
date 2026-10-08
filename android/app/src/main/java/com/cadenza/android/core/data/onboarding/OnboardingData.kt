package com.cadenza.android.core.data.onboarding

// iOS Onboarding 선택지 룩업 테이블 — Repository 정적 데이터와 동일한 내용

object OnboardingData {

    val majors = listOf(
        "성악", "피아노", "바이올린", "비올라", "첼로", "콘트라베이스",
        "플루트", "오보에", "클라리넷", "바순", "호른", "트럼펫", "트롬본",
        "튜바", "타악기", "하프", "기타", "작곡", "지휘", "음악학", "음악교육",
        "재즈", "국악", "뮤지컬", "전자음악", "음악치료"
    )

    val instruments = listOf(
        "피아노", "바이올린", "비올라", "첼로", "콘트라베이스",
        "플루트", "오보에", "클라리넷", "바순", "호른", "트럼펫", "트롬본",
        "튜바", "타악기", "하프", "기타(클래식)", "오르간",
        "소프라노", "메조소프라노", "알토", "테너", "바리톤", "베이스",
        "작곡/지휘", "그 외"
    )

    val cities = listOf(
        "서울", "부산", "대구", "인천", "광주", "대전", "수원",
        "Berlin", "München", "Hamburg", "Frankfurt", "Leipzig", "Köln",
        "Vienna", "Salzburg", "Graz",
        "New York", "Los Angeles", "Chicago", "San Francisco", "Boston",
        "London", "Paris", "Amsterdam", "Zurich", "Milan", "Rome",
        "Tokyo", "Osaka", "Beijing", "Shanghai", "Sydney"
    )

    val schools = listOf(
        // 한국
        "서울대학교", "연세대학교", "고려대학교", "한국예술종합학교", "이화여자대학교",
        "성신여자대학교", "숙명여자대학교", "경희대학교", "중앙대학교", "단국대학교",
        "부산대학교", "전남대학교", "전북대학교",
        // 독일/오스트리아
        "Hochschule für Musik und Theater Hamburg",
        "Hochschule für Musik Hanns Eisler Berlin",
        "Universität der Künste Berlin",
        "Hochschule für Musik und Theater München",
        "Hochschule für Musik Frankfurt",
        "Hochschule für Musik Köln",
        "Hochschule für Musik Freiburg",
        "Hochschule für Musik Würzburg",
        "Hochschule für Musik Karlsruhe",
        "Hochschule für Musik Detmold",
        "Hochschule für Musik und Theater Rostock",
        "Hochschule für Musik und Darstellende Kunst Stuttgart",
        "Universität Mozarteum Salzburg",
        "Universität für Musik und darstellende Kunst Wien",
        "Kunstuniversität Graz",
        // 미국
        "The Juilliard School",
        "Curtis Institute of Music",
        "New England Conservatory",
        "Peabody Institute",
        "Eastman School of Music",
        "San Francisco Conservatory of Music",
        "Yale School of Music",
        "Manhattan School of Music",
        "Cleveland Institute of Music",
        "Rice University — Shepherd School of Music",
        "Indiana University Jacobs School of Music",
        "Northwestern University Bienen School of Music",
        // 영국/기타
        "Royal Academy of Music",
        "Royal College of Music",
        "Guildhall School of Music & Drama",
        "Conservatoire de Paris (CNSMDP)",
        "Conservatorio di Santa Cecilia",
        "Hochschule für Musik Zürich"
    )

    val courseTypes = listOf(
        "학사", "석사", "박사", "최고연주자과정", "아티스트 디플로마",
        "전문학사", "단기과정", "교환학생"
    )
}
