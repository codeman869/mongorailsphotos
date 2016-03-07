class Point

	attr_accessor :longitude, :latitude

	def initialize(params)
		if params[:coordinates] == nil
			@latitude = params[:lat]
			@longitude = params[:lng]
		else
			@latitude = params[:coordinates][1]
			@longitude = params[:coordinates][0]
		end
		
	end

	def to_hash
		{"type": "Point", "coordinates": [@longitude,@latitude]}
	end
end