require 'rubygems'
require 'redis'
require 'json'

NO_OF_RECORDS 		= 1800000
NO_OF_BUCKET 		= (ENV['NO_OF_BUCKET'] || 1000).to_i
INDEX_CHANNEL 		= "INDEX_CHANNEL"
POST_INDEX_CHANNEL 	= "INDEX_DONE"
NUMBER_OF_WORKERS 	= (ENV['NUMBER_OF_WORKERS'] || 50).to_i

$redis = Redis.new(:timeout => 0)
def index
	(1..NO_OF_RECORDS).step(NO_OF_BUCKET).each_with_index do |p, i|
		$redis.lpush INDEX_CHANNEL, Marshal.dump([p, (i+1) * NO_OF_BUCKET])		
	end		
end	

def wait_for_index_completion
	puts "Waiting for indexer workers..."
	pending_workers = NUMBER_OF_WORKERS
	$redis.subscribe(POST_INDEX_CHANNEL) do |on|
		on.message do |channel, msg|
			data = JSON.parse(msg)
			puts "1 Worker completed indexing - #{data['id']}"
			pending_workers = pending_workers - 1

			if pending_workers.zero?
				puts "Orchestration complete."		
				exit 0
			end				
		end		
	end	
end	

index()
wait_for_index_completion()




