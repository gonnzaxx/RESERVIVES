from datetime import date, time, timezone

from app.utils.datetime_utils import local_slot_to_utc_range


def test_local_slot_to_utc_range_in_summer_dst():
    # Europe/Madrid in July is UTC+2
    start_utc, end_utc = local_slot_to_utc_range(
        date(2026, 7, 1),
        time(11, 10),
        time(12, 5),
    )

    assert start_utc.tzinfo == timezone.utc
    assert end_utc.tzinfo == timezone.utc
    assert start_utc.hour == 9
    assert start_utc.minute == 10
    assert end_utc.hour == 10
    assert end_utc.minute == 5


def test_local_slot_to_utc_range_in_winter():
    # Europe/Madrid in January is UTC+1
    start_utc, end_utc = local_slot_to_utc_range(
        date(2026, 1, 15),
        time(11, 10),
        time(12, 5),
    )

    assert start_utc.tzinfo == timezone.utc
    assert end_utc.tzinfo == timezone.utc
    assert start_utc.hour == 10
    assert start_utc.minute == 10
    assert end_utc.hour == 11
    assert end_utc.minute == 5
