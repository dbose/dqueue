# Newrelic custom metric
#
require 'rubygems'
require 'redis'
require 'json'

NO_OF_RECORDS 			= 1800000
NO_OF_BUCKET 			= (ENV['NO_OF_BUCKET'] || 10000).to_i
INDEX_CHANNEL 			= "INDEX_CHANNEL"
POST_INDEX_CHANNEL 		= "INDEX_DONE"
WORKER_COUNT_CHANNEL	= "WORKER_COUNT_CHANNEL"
# NUMBER_OF_WORKERS 	= (ENV['NUMBER_OF_WORKERS'] || 50).to_i

def entry
	redis = Redis.new
	redis.watch(INDEX_CHANNEL) do
	  unless redis.exists(INDEX_CHANNEL)
	    redis.multi do |multi|
	      master_job()
	    end
	  else
	    redis.unwatch
	    slave_job()
	  end
	end	
end	

$redis = Redis.new(:timeout => 0)

def master_job
	(1..NO_OF_RECORDS).step(NO_OF_BUCKET).each_with_index do |p, i|
		$redis.lpush INDEX_CHANNEL, Marshal.dump([p, (i+1) * NO_OF_BUCKET])		
	end	

	wait_for_index_completion()	
end	

def slave_job
	indexer_worker()
end

def indexer_worker
	Process.fork do
	    redis = Redis.new
	    redis.incr WORKER_COUNT_CHANNEL
	    
	    loop do
	    	val = redis.brpop INDEX_CHANNEL, 5
			unless val
				puts "Process: #{Process.pid} is exiting"
				
				# signal when done
				redis.multi do
					redis.decr WORKER_COUNT_CHANNEL
					redis.publish POST_INDEX_CHANNEL, {'id' => Process.pid}.to_json 
				end	
				
				exit 0
			end

			from, to = Marshal.load val.last
			puts "Indexing range: #{from} - #{to}"

			sleep(Random.new.rand(10))

			puts "Indexed range: #{from} - #{to}"
	    end	
	end
end	

def wait_for_index_completion
	puts "Waiting for indexer workers..."	
	$redis.subscribe(POST_INDEX_CHANNEL) do |on|
		on.message do |channel, msg|
			data = JSON.parse(msg)
			puts "1 Worker completed indexing - #{data['id']}"
			
			worker_count = $redis.get WORKER_COUNT_CHANNEL
			if worker_count.to_i.zero?
				puts "Orchestration complete."		
				exit 0
			end				
		end		
	end	
end	

#suspend_realtime_queue()
# index()
# wait_for_index_completion()

entry()
#start_realtime_queue()





