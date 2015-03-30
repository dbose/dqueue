require 'rubygems'
require 'redis'
require 'json'

NUMBER_OF_WORKERS 	= (ENV['NUMBER_OF_WORKERS'] || 50).to_i
INDEX_CHANNEL 		= "INDEX_CHANNEL"
POST_INDEX_CHANNEL 	= "INDEX_DONE"

def indexer_worker(workers)
	workers.times do
	  Process.fork do
	    redis = Redis.new
	    
	    loop do
	    	val = redis.brpop INDEX_CHANNEL, 5
			unless val
				puts "Process: #{Process.pid} is exiting"
				
				# signal when done
				redis.publish POST_INDEX_CHANNEL, {'id' => Process.pid}.to_json 

				exit 0
			end

			from, to = Marshal.load val.last
			puts "Indexing range: #{from} - #{to}"

			sleep(Random.new.rand(10))

			puts "Indexed range: #{from} - #{to}"
	    end	

	  end
	end
end	

indexer_worker(NUMBER_OF_WORKERS)