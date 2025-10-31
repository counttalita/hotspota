defmodule HotspotApi.Monetization do
  @moduledoc """
  The Monetization context for managing partners and sponsored alerts.
  """

  import Ecto.Query, warn: false
  alias HotspotApi.Repo
  alias HotspotApi.Monetization.{Partner, SponsoredAlert}

  @doc """
  Lists all partners with optional filtering.
  """
  def list_partners(filters \\ %{}) do
    Partner
    |> apply_partner_filters(filters)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists partners with pagination.
  """
  def list_partners_paginated(page, page_size, filters \\ %{}) do
    query = Partner
    |> apply_partner_filters(filters)

    total_count = Repo.aggregate(query, :count, :id)

    partners = query
      |> order_by([p], desc: p.inserted_at)
      |> limit(^page_size)
      |> offset(^((page - 1) * page_size))
      |> Repo.all()

    total_pages = ceil(total_count / page_size)

    %{
      partners: partners,
      total_count: total_count,
      page: page,
      page_size: page_size,
      total_pages: total_pages
    }
  end

  defp apply_partner_filters(query, filters) do
    query
    |> filter_by_active_status(Map.get(filters, :is_active))
    |> filter_by_partner_type(Map.get(filters, :partner_type))
    |> filter_by_search(Map.get(filters, :search))
  end

  defp filter_by_active_status(query, nil), do: query
  defp filter_by_active_status(query, ""), do: query
  defp filter_by_active_status(query, "true"), do: where(query, [p], p.is_active == true)
  defp filter_by_active_status(query, "false"), do: where(query, [p], p.is_active == false)
  defp filter_by_active_status(query, true), do: where(query, [p], p.is_active == true)
  defp filter_by_active_status(query, false), do: where(query, [p], p.is_active == false)
  defp filter_by_active_status(query, _), do: query

  defp filter_by_partner_type(query, nil), do: query
  defp filter_by_partner_type(query, ""), do: query
  defp filter_by_partner_type(query, type), do: where(query, [p], p.partner_type == ^type)

  defp filter_by_search(query, nil), do: query
  defp filter_by_search(query, ""), do: query
  defp filter_by_search(query, search_term) do
    search_pattern = "%#{search_term}%"
    where(query, [p], ilike(p.name, ^search_pattern) or ilike(p.contact_email, ^search_pattern))
  end

  @doc """
  Gets a single partner.
  """
  def get_partner!(id) do
    Repo.get!(Partner, id)
  end

  @doc """
  Gets a partner with preloaded sponsored alerts.
  """
  def get_partner_with_stats!(id) do
    Partner
    |> Repo.get!(id)
    |> Repo.preload(:sponsored_alerts)
  end

  @doc """
  Creates a partner.
  """
  def create_partner(attrs \\ %{}) do
    %Partner{}
    |> Partner.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a partner.
  """
  def update_partner(%Partner{} = partner, attrs) do
    partner
    |> Partner.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a partner.
  """
  def delete_partner(%Partner{} = partner) do
    Repo.delete(partner)
  end

  @doc """
  Gets partner statistics including impressions, clicks, and revenue.
  """
  def get_partner_stats(partner_id, start_date \\ nil, end_date \\ nil) do
    # Default to last 30 days if not provided
    end_date = end_date || DateTime.utc_now()
    start_date = start_date || DateTime.add(end_date, -30, :day)

    partner = get_partner!(partner_id)

    # Get sponsored alert stats
    stats_query = from(sa in SponsoredAlert,
      where: sa.partner_id == ^partner_id,
      where: sa.inserted_at >= ^start_date and sa.inserted_at <= ^end_date,
      select: %{
        total_impressions: sum(sa.impression_count),
        total_clicks: sum(sa.click_count),
        total_alerts: count(sa.id)
      }
    )

    stats = Repo.one(stats_query) || %{
      total_impressions: 0,
      total_clicks: 0,
      total_alerts: 0
    }

    # Calculate CTR (Click-Through Rate)
    ctr = if stats.total_impressions > 0 do
      Float.round(stats.total_clicks / stats.total_impressions * 100, 2)
    else
      0.0
    end

    # Calculate revenue (monthly fee * months in period)
    days_in_period = DateTime.diff(end_date, start_date, :day)
    months_in_period = max(1, div(days_in_period, 30))
    revenue = if partner.monthly_fee do
      Decimal.mult(partner.monthly_fee, Decimal.new(months_in_period))
    else
      Decimal.new(0)
    end

    %{
      total_impressions: stats.total_impressions || 0,
      total_clicks: stats.total_clicks || 0,
      total_alerts: stats.total_alerts || 0,
      click_through_rate: ctr,
      revenue: revenue,
      monthly_fee: partner.monthly_fee || Decimal.new(0)
    }
  end

  @doc """
  Creates a sponsored alert linking a partner to an incident.
  """
  def create_sponsored_alert(attrs \\ %{}) do
    %SponsoredAlert{}
    |> SponsoredAlert.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Increments impression count for a sponsored alert.
  """
  def increment_impression(partner_id, incident_id) do
    case Repo.get_by(SponsoredAlert, partner_id: partner_id, incident_id: incident_id) do
      nil ->
        create_sponsored_alert(%{
          partner_id: partner_id,
          incident_id: incident_id,
          impression_count: 1,
          click_count: 0
        })

      sponsored_alert ->
        sponsored_alert
        |> Ecto.Changeset.change(impression_count: sponsored_alert.impression_count + 1)
        |> Repo.update()
    end
  end

  @doc """
  Increments click count for a sponsored alert.
  """
  def increment_click(partner_id, incident_id) do
    case Repo.get_by(SponsoredAlert, partner_id: partner_id, incident_id: incident_id) do
      nil ->
        create_sponsored_alert(%{
          partner_id: partner_id,
          incident_id: incident_id,
          impression_count: 0,
          click_count: 1
        })

      sponsored_alert ->
        sponsored_alert
        |> Ecto.Changeset.change(click_count: sponsored_alert.click_count + 1)
        |> Repo.update()
    end
  end
end
