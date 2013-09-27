module Api
  module V1
    class YearsController < ApiController

      def index
        data = {
          '2013' => [2010, 2010],
          '2012' => [2012, 2012],
          '2011' => [2011, 2011],
          '2010' => [2010, 2010],
          '2010' => [2010, 2010],
          '2009' => [2009, 2009],
          '2004' => [2004, 2004],
          '2003' => [2003, 2003],
          '2002' => [2002, 2002],
          '2001' => [2001, 2001],
          '2000' => [2000, 2000],
          '1999' => [1999, 1999],
          '1998' => [1998, 1998],
          '1997' => [1997, 1997],
          '1996' => [1996, 1996],
          '1995' => [1995, 1995],
          '1994' => [1994, 1994],
          '1993' => [1993, 1993],
          '1992' => [1992, 1992],
          '1991' => [1991, 1991],
          '1990' => [1990, 1990],
          '1989' => [1989, 1989],
          '1988' => [1988, 1988],
          '1983-1987' => [1983, 1987]
        }
        respond_with_success(data)
      end

      def show
        if params[:id].match /^(\d{4})-(\d+{4})$/
          shows = Show.between_years($1, $2).includes(:venue).order('date asc').all
        elsif params[:id].match /^(\d){4}$/
          shows = Show.during_year(params[:id]).includes(:venue).order('date asc').all
        else
          respond_with_failure('Invalid year or year range') and return
        end
        respond_with_success(shows)
      end

    end
  end
end