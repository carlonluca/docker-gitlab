use_s3_caching !ENV['USE_S3_CACHE'].nil? && !ENV['USE_S3_CACHE'].casecmp("false").zero?
s3_access_key ENV['CACHE_AWS_ACCESS_KEY_ID']
s3_secret_key ENV['CACHE_AWS_SECRET_ACCESS_KEY']
s3_bucket ENV['CACHE_AWS_BUCKET']
s3_region ENV['CACHE_AWS_S3_REGION']
s3_endpoint ENV['CACHE_AWS_S3_ENDPOINT']
s3_accelerate !ENV['CACHE_S3_ACCELERATE'].nil? && !ENV['CACHE_S3_ACCELERATE'].casecmp("false").zero?

build_retries 2
fetcher_retries 5
fetcher_progress_bar false
append_timestamp false
