module Moshy
	class ISplit
		def initialize(args)
			opts = Slop::Options.new
			opts.banner = "Usage: moshy -m isplit -i file.avi -o file_out\nmoshy -m isplit --help for details"
			opts.separator 'Required Parameters:'
			opts.string '-i', '--input', 'Input file path - must be an .avi.'
			opts.string '-o', '--output', 'Output file path - will be appended with -#.avi for each clip.'
			opts.separator 'Optional Parameters:'
			opts.integer '-b', '--begin', 'Index of the I-frame at which to begin clipping (inclusive)'
			opts.integer '-e', '--end', 'Index of the I-frame at which to stop clipping (inclusive)'
			opts.on '-h', '--help' do
				puts opts
				puts "\n"
				puts \
"Extracts individual clips from an AVI where each clip is separated
by I-frames in the original AVI. Great for getting specific clips out
of a larger video and later doing I-frame moshing.

Note that since this creates multiple clips, you should NOT specify
the .avi extension in your output (-o) parameter, as moshy will
automatically append \"-#.avi\" to the output parameter you pass
when it spits out individual clips.

If you want to only cut clips from a certain section of a larger
video file, you can set the in- and out-points of where to get clips
from by using the -b (--begin) and -e (--end) options, where the
values used in those parameters are the video frame indexes to start
and stop at.

For example, if you have a file that has 800 frames, and you know you
want the clips that occur around frames 200 to 600, you could use the
following command to do that:

moshy -m isplit -i file.avi -o file_out -b 200 -e 600

Note that isplit cuts specifically at I-Frames, meaning that if you
have used the above command and have an I-Frame at frame 180 and an
I-Frame at frame 240, you will NOT get the clip 180 - 240 nor a clip
made of frames 200 to 240, but you will get all clips after frame 240."
				exit
			end

			parser = Slop::Parser.new(opts)
			@options = parser.parse(ARGV)
			# puts @options.to_hash

			# Check mandatory params
			mandatory = [:input, :output]
			missing = mandatory.select{ |param| @options[param].nil? }
			unless missing.empty?
				puts "Missing options: #{missing.join(', ')}"
				puts @options
				exit
			end


			puts "Opening file " + @options[:input] + "..."
			a = AviGlitch.open @options[:input]       # Rewrite this line for your file.
			puts "Opened!"

			split(a)
		end

		def clip(frames, out_path, start_index, frame_count)
			puts "Clipping " + frame_count.to_s + " frames starting at frame " + start_index.to_s
			clip = frames.slice(start_index, frame_count)
			o = AviGlitch.open clip
			puts "Outputting " + out_path
			o.output out_path
		end

		def split(clip)
			clip_cuts = {}

			clip_count = 0
			current_iframe = 0
			iframe_index = 0
			last_iframe_index = 0
			frames_in_clip = 0

			# Harvest clip details
			total_frame_count = clip.frames.count
			clip.frames.each_with_index do |f, i|
				if f.is_keyframe?
					iframe_index = i
					# Don't process frames that are before our beginning
					if current_iframe and @options[:begin] and current_iframe < @options[:begin]
						# puts "skipping " + current_iframe.to_s
						frames_in_clip = 0
						current_iframe = current_iframe + 1
						last_iframe_index = iframe_index
						# puts "last_iframe_index: " + last_iframe_index.to_s
						next
					end
					break if @options[:end] and current_iframe > @options[:end]

					if current_iframe != 0
						if @options[:verbose]
							puts "Storing clip details: iframe_number=" + current_iframe.to_s + "; index=" + last_iframe_index.to_s + "; frame_count=" + frames_in_clip.to_s
						end
						clip_cuts[current_iframe] = {
							:index => last_iframe_index,
							:frame_count => frames_in_clip
						}
					end
					frames_in_clip = 0
					current_iframe = current_iframe + 1
					last_iframe_index = iframe_index
				else
					frames_in_clip = frames_in_clip + 1
					# clip last piece manually if we're at the end, because there's
					# no last iframe to detect and trigger the final clip
					if i == total_frame_count - 1
						if @options[:verbose]
							puts "Storing clip details: iframe_number=" + current_iframe.to_s + "; index=" + last_iframe_index.to_s + "; frame_count=" + frames_in_clip.to_s
						end
						clip_cuts[current_iframe] = {
							:index => last_iframe_index,
							:frame_count => frames_in_clip
						}
					end
				end
			end

			puts clip_cuts

			clip_cuts.keys.each do |f|
				out_path = @options[:output] + '-' + f.to_s + '.avi'
				clip(clip.frames, out_path, clip_cuts[f][:index], clip_cuts[f][:frame_count])
			end

			puts "All done!"
		end
	end
end
