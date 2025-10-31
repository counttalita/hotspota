defmodule HotspotApi.EmergencyServicesTest do
  use ExUnit.Case, async: true

  alias HotspotApi.EmergencyServices

  describe "find_nearby_police_stations/3" do
    test "returns list of police stations" do
      # Johannesburg coordinates
      latitude = -26.2041
      longitude = 28.0473
      radius = 5000

      {:ok, stations} = EmergencyServices.find_nearby_police_stations(latitude, longitude, radius)

      assert is_list(stations)
      # Should return mock data when API key is not configured
      assert length(stations) > 0

      station = List.first(stations)
      assert Map.has_key?(station, :place_id)
      assert Map.has_key?(station, :name)
      assert Map.has_key?(station, :address)
      assert Map.has_key?(station, :location)
      assert Map.has_key?(station.location, :latitude)
      assert Map.has_key?(station.location, :longitude)
    end
  end

  describe "find_nearby_hospitals/3" do
    test "returns list of hospitals" do
      latitude = -26.2041
      longitude = 28.0473
      radius = 5000

      {:ok, hospitals} = EmergencyServices.find_nearby_hospitals(latitude, longitude, radius)

      assert is_list(hospitals)
      assert length(hospitals) > 0

      hospital = List.first(hospitals)
      assert Map.has_key?(hospital, :place_id)
      assert Map.has_key?(hospital, :name)
      assert Map.has_key?(hospital, :address)
      assert Map.has_key?(hospital, :location)
    end
  end

  describe "find_all_emergency_services/3" do
    test "returns both police stations and hospitals" do
      latitude = -26.2041
      longitude = 28.0473
      radius = 5000

      {:ok, services} = EmergencyServices.find_all_emergency_services(latitude, longitude, radius)

      assert Map.has_key?(services, :police_stations)
      assert Map.has_key?(services, :hospitals)
      assert is_list(services.police_stations)
      assert is_list(services.hospitals)
      assert length(services.police_stations) > 0
      assert length(services.hospitals) > 0
    end
  end

  describe "calculate_distance_and_eta/4" do
    test "calculates distance and ETA between two points" do
      # Johannesburg to Pretoria (approximately 50km)
      from_lat = -26.2041
      from_lng = 28.0473
      to_lat = -25.7479
      to_lng = 28.2293

      result = EmergencyServices.calculate_distance_and_eta(from_lat, from_lng, to_lat, to_lng)

      assert Map.has_key?(result, :distance_meters)
      assert Map.has_key?(result, :distance_text)
      assert Map.has_key?(result, :duration_seconds)
      assert Map.has_key?(result, :duration_text)

      # Distance should be approximately 50km (50000 meters)
      assert result.distance_meters > 40000
      assert result.distance_meters < 60000

      # Duration should be reasonable (around 1 hour at 40km/h)
      assert result.duration_seconds > 3000
      assert result.duration_seconds < 6000

      # Text formats should be present
      assert String.contains?(result.distance_text, "km")
      assert String.contains?(result.duration_text, "hr") or String.contains?(result.duration_text, "min")
    end

    test "formats short distances correctly" do
      # Very close points (about 500 meters)
      from_lat = -26.2041
      from_lng = 28.0473
      to_lat = -26.2086
      to_lng = 28.0473

      result = EmergencyServices.calculate_distance_and_eta(from_lat, from_lng, to_lat, to_lng)

      # Distance should be less than 1km
      assert result.distance_meters < 1000
      assert String.contains?(result.distance_text, "m")
      refute String.contains?(result.distance_text, "km")
    end
  end
end
