"""DST-aware broker time + session detection tests.

Veritier bahwa waktu broker (Europe/Bucharest, EET/EEST) dihitung dari IANA
tz database sehingga tidak ada offset skalar hardcoded, dan bahwa window
sesi tidak bergeser di sekitar transisi DST (akhir Maret dan akhir Oktober).
"""
import datetime as dt

from services.advanced import (
    convert_utc_to_broker_time,
    detect_session,
    broker_utc_offset_hours,
)

UTC = dt.timezone.utc


def _utc(y, m, d, h=12):
    return dt.datetime(y, m, d, h, tzinfo=UTC)


def test_dst_winter_offset_is_plus_2():
    assert broker_utc_offset_hours(_utc(2026, 1, 15)) == 2.0


def test_dst_summer_offset_is_plus_3():
    assert broker_utc_offset_hours(_utc(2026, 7, 15)) == 3.0


def test_dst_spring_transition_shifts_broker_clock():
    # 28 Mar 2026 masih EET (+2), 30 Mar 2026 sudah EEST (+3).
    before = convert_utc_to_broker_time(_utc(2026, 3, 28, 12))
    after = convert_utc_to_broker_time(_utc(2026, 3, 30, 12))
    assert before.utcoffset() == dt.timedelta(hours=2)
    assert after.utcoffset() == dt.timedelta(hours=3)
    assert before.hour == 14  # 12 UTC + 2
    assert after.hour == 15  # 12 UTC + 3


def test_dst_autumn_transition_shifts_broker_clock():
    # 25 Okt 2025 masih EEST (+3), 27 Okt 2025 sudah EET (+2).
    before = convert_utc_to_broker_time(_utc(2025, 10, 25, 12))
    after = convert_utc_to_broker_time(_utc(2025, 10, 27, 12))
    assert before.utcoffset() == dt.timedelta(hours=3)
    assert after.utcoffset() == dt.timedelta(hours=2)
    assert before.hour == 15  # 12 UTC + 3
    assert after.hour == 14  # 12 UTC + 2


def test_session_hour_follows_broker_clock_across_dst():
    # Jam 06:00 UTC: broker EET (winter) = 08:00 (London aktif),
    # broker EEST (summer) = 09:00 (London tetap aktif) -> tidak bergeser keluar.
    s = detect_session(_utc(2026, 1, 15, 6))
    assert s["hour_broker"] == 8.0
    assert "LONDON" in s["active_sessions"]
    s2 = detect_session(_utc(2026, 7, 15, 6))
    assert s2["hour_broker"] == 9.0
    assert "LONDON" in s2["active_sessions"]


def test_session_reports_utc_and_offset():
    s = detect_session(_utc(2026, 7, 15, 6))
    assert s["hour_utc"] == 6.0
    assert s["broker_tz"] == "Europe/Bucharest"
    assert s["broker_utc_offset_h"] == 3.0


def test_session_legacy_utc_mode():
    s = detect_session(_utc(2026, 7, 15, 6), broker_tz="UTC")
    assert s["hour_broker"] == 6.0
    assert s["broker_utc_offset_h"] == 0.0