defmodule HotspotApi.Moderation.TextFilter do
  @moduledoc """
  Text filtering and sanitization module.
  Handles profanity filtering, hate speech detection, and XSS prevention.
  """

  # Common profanity words - this is a minimal list for demonstration
  # In production, use a comprehensive profanity filter library or API
  @profanity_words [
    "fuck", "fucking", "fucked", "fucker",
    "shit", "shitting", "shitty",
    "damn", "damned",
    "bitch", "bitching",
    "asshole", "ass",
    "bastard",
    "cunt",
    "dick",
    "pussy",
    "cock",
    "piss",
    "whore"
  ]

  # Hate speech patterns - simplified for demonstration
  # In production, use ML-based hate speech detection API
  @hate_speech_patterns [
    ~r/\b(kill|murder|die)\s+(all|every)\s+\w+/i,
    ~r/\b(hate|despise)\s+\w+\s+(people|race|religion)/i
  ]

  @doc """
  Filters profanity from text by replacing offensive words with asterisks.
  """
  def filter_profanity(text) when is_binary(text) do
    filtered_text = Enum.reduce(@profanity_words, text, fn word, acc ->
      # Case-insensitive replacement - need to handle the match properly
      pattern = ~r/\b#{Regex.escape(word)}\b/iu

      # Replace with asterisks matching the length of the matched word
      String.replace(acc, pattern, fn matched ->
        String.duplicate("*", String.length(matched))
      end)
    end)

    {:ok, filtered_text}
  end

  def filter_profanity(_), do: {:error, :invalid_input}

  @doc """
  Detects hate speech in text.
  Returns {:ok, text} if clean, {:error, :hate_speech_detected} if problematic.
  """
  def detect_hate_speech(text) when is_binary(text) do
    has_hate_speech = Enum.any?(@hate_speech_patterns, fn pattern ->
      Regex.match?(pattern, text)
    end)

    if has_hate_speech do
      {:error, :hate_speech_detected, "Content contains hate speech"}
    else
      {:ok, text}
    end
  end

  def detect_hate_speech(_), do: {:error, :invalid_input}

  @doc """
  Escapes HTML to prevent XSS attacks.
  """
  def escape_html(text) when is_binary(text) do
    safe_text = Phoenix.HTML.html_escape(text)
    |> Phoenix.HTML.safe_to_string()

    {:ok, safe_text}
  end

  def escape_html(_), do: {:error, :invalid_input}

  @doc """
  Sanitizes text by applying all filters.
  """
  def sanitize(text) when is_binary(text) do
    with {:ok, filtered} <- filter_profanity(text),
         {:ok, checked} <- detect_hate_speech(filtered),
         {:ok, safe} <- escape_html(checked) do
      {:ok, safe}
    end
  end

  def sanitize(_), do: {:error, :invalid_input}

  @doc """
  Checks if text contains profanity (for client-side preview).
  """
  def contains_profanity?(text) when is_binary(text) do
    Enum.any?(@profanity_words, fn word ->
      Regex.match?(~r/\b#{Regex.escape(word)}\b/i, text)
    end)
  end

  def contains_profanity?(_), do: false
end
