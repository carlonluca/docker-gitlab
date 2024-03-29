module SuggestedReviewers
  class << self
    def parse_secrets
      Gitlab['suggested_reviewers']['api_secret_key'] ||= Base64.strict_encode64(SecretsHelper.generate_hex(16))
    end

    def validate_secrets
      return unless Gitlab['suggested_reviewers']['api_secret_key']

      # Suggested Reviewers and GitLab expects exactly 32 bytes, encoded with base64
      api_secret_key = Base64.strict_decode64(Gitlab['suggested_reviewers']['api_secret_key'])
      raise "suggested_reviewers['api_secret_key'] should be exactly 32 bytes" if api_secret_key.length != 32
    end
  end
end
