from datetime import date

from app.routers.admin import _matches_calendar_filters


def test_matches_calendar_filters_by_day():
    target = date(2026, 4, 27)
    assert _matches_calendar_filters(target, day=date(2026, 4, 27), month=None, year=None)
    assert not _matches_calendar_filters(target, day=date(2026, 4, 26), month=None, year=None)


def test_matches_calendar_filters_by_month_and_year():
    target = date(2026, 4, 27)
    assert _matches_calendar_filters(target, day=None, month=4, year=2026)
    assert not _matches_calendar_filters(target, day=None, month=5, year=2026)
