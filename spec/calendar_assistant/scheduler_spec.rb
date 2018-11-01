describe CalendarAssistant::Scheduler do
  describe "#initialize" do
    it "needs a test"
  end

  describe "#available_blocks" do
    let(:scheduler) { described_class.new ca, config: config }
    let(:config) { CalendarAssistant::Config.new }
    let(:ca) { instance_double(CalendarAssistant) }

    before do
      expect(ca).to receive(:find_events).with(time_range).and_return(events)
    end

    context "single date" do
      let(:time_range) { CalendarAssistant::CLIHelpers.parse_datespec "today" }
      let(:date) { time_range.first.to_date }

      context "with an event at the end of the day and other events later" do
        let(:events) do
          [
            event_factory("first", Chronic.parse("8:30am")..(Chronic.parse("10am"))),
            event_factory("second", Chronic.parse("10:30am")..(Chronic.parse("12pm"))),
            event_factory("third", Chronic.parse("1:30pm")..(Chronic.parse("2:30pm"))),
            event_factory("fourth", Chronic.parse("3pm")..(Chronic.parse("5pm"))),
            event_factory("fifth", Chronic.parse("5:30pm")..(Chronic.parse("6pm"))),
            event_factory("fourth", Chronic.parse("6:30pm")..(Chronic.parse("7pm"))),
          ]
        end

        let(:expected_avails) do
          {
            date => [
              event_factory("available", Chronic.parse("10am")..Chronic.parse("10:30am")),
              event_factory("available", Chronic.parse("12pm")..Chronic.parse("1:30pm")),
              event_factory("available", Chronic.parse("2:30pm")..Chronic.parse("3pm")),
              event_factory("available", Chronic.parse("5pm")..Chronic.parse("5:30pm")),
            ]
          }
        end

        before do
          events.each { |e| allow(e).to receive(:accepted?).and_return(true) }
        end

        it "returns a hash of date => chunks-of-free-time-longer-than-min-duration" do
          found_avails = scheduler.available_blocks time_range

          expect(found_avails.keys).to eq([date])
          expect(found_avails[date].length).to eq(expected_avails[date].length)
          found_avails[date].each_with_index do |found_avail, j|
            expect(found_avail.start).to eq(expected_avails[date][j].start)
            expect(found_avail.end).to eq(expected_avails[date][j].end)
          end
        end

        context "some meetings haven't been accepted" do
          before do
            allow(events[1]).to receive(:accepted?).and_return(false)
          end

          let(:expected_avails) do
            {
              date => [
                event_factory("available", Chronic.parse("10am")..Chronic.parse("1:30pm")),
                event_factory("available", Chronic.parse("2:30pm")..Chronic.parse("3pm")),
                event_factory("available", Chronic.parse("5pm")..Chronic.parse("5:30pm")),
              ]
            }
          end

          it "ignores meetings that are not accepted" do
            found_avails = scheduler.available_blocks time_range

            expect(found_avails.keys).to eq([date])
            expect(found_avails[date].length).to eq(expected_avails[date].length)
            found_avails[date].each_with_index do |found_avail, j|
              expect(found_avail.start).to eq(expected_avails[date][j].start)
              expect(found_avail.end).to eq(expected_avails[date][j].end)
            end
          end
        end
      end

      context "single date with no event at the end of the day" do
        let(:time_range) { CalendarAssistant::CLIHelpers.parse_datespec "today" }
        let(:date) { time_range.first.to_date }

        let(:events) do
          [
            event_factory("first", Chronic.parse("8:30am")..(Chronic.parse("10am"))),
            event_factory("second", Chronic.parse("10:30am")..(Chronic.parse("12pm"))),
            event_factory("third", Chronic.parse("1:30pm")..(Chronic.parse("2:30pm"))),
            event_factory("fourth", Chronic.parse("3pm")..(Chronic.parse("5pm"))),
          ]
        end

        let(:expected_avails) do
          {
            date => [
              event_factory("available", Chronic.parse("10am")..Chronic.parse("10:30am")),
              event_factory("available", Chronic.parse("12pm")..Chronic.parse("1:30pm")),
              event_factory("available", Chronic.parse("2:30pm")..Chronic.parse("3pm")),
              event_factory("available", Chronic.parse("5pm")..Chronic.parse("6pm")),
            ]
          }
        end

        before do
          events.each { |e| allow(e).to receive(:accepted?).and_return(true) }
        end

        it "finds chunks of free time at the end of the day" do
          found_avails = scheduler.available_blocks time_range

          expect(found_avails.keys).to eq([date])
          expect(found_avails[date].length).to eq(expected_avails[date].length)
          found_avails[date].each_with_index do |found_avail, j|
            expect(found_avail.start).to eq(expected_avails[date][j].start)
            expect(found_avail.end).to eq(expected_avails[date][j].end)
          end
        end
      end

      context "completely free day with no events" do
        let(:time_range) { CalendarAssistant::CLIHelpers.parse_datespec "today" }
        let(:date) { time_range.first.to_date }

        let(:events) { [] }
        let(:expected_avails) do
          {
            date => [
              event_factory("available", Chronic.parse("9am")..Chronic.parse("6pm")),
            ]
          }
        end

        it "returns a big fat available block" do
          found_avails = scheduler.available_blocks time_range

          expect(found_avails.keys).to eq([date])
          expect(found_avails[date].length).to eq(expected_avails[date].length)
          found_avails[date].each_with_index do |found_avail, j|
            expect(found_avail.start).to eq(expected_avails[date][j].start)
            expect(found_avail.end).to eq(expected_avails[date][j].end)
          end
        end
      end
    end

    describe "multiple days" do
      let(:time_range) { CalendarAssistant::CLIHelpers.parse_datespec "2018-01-01..2018-01-03" }
      let(:events) { [] }
      let(:expected_avails) do
        {
          Date.parse("2018-01-01") => [event_factory("available", Chronic.parse("2018-01-01 9am")..Chronic.parse("2018-01-01 6pm"))],
          Date.parse("2018-01-02") => [event_factory("available", Chronic.parse("2018-01-02 9am")..Chronic.parse("2018-01-02 6pm"))],
          Date.parse("2018-01-03") => [event_factory("available", Chronic.parse("2018-01-03 9am")..Chronic.parse("2018-01-03 6pm"))],
        }
      end

      it "returns a hash of all dates" do
        found_avails = scheduler.available_blocks time_range

        expect(found_avails.keys).to eq(expected_avails.keys)
        expected_avails.keys.each do |date|
          expect(found_avails[date].length).to eq(1)
          expect(found_avails[date].first.start).to eq(expected_avails[date].first.start)
          expect(found_avails[date].first.end).to eq(expected_avails[date].first.end)
        end
      end
    end

    describe "configurable parameters" do
      let(:config) do
        CalendarAssistant::Config.new options: options
      end

      let(:time_range) { CalendarAssistant::CLIHelpers.parse_datespec "today" }
      let(:date) { time_range.first.to_date }

      let(:events) do
        [
          event_factory("first", Chronic.parse("8:30am")..(Chronic.parse("10am"))),
          event_factory("second", Chronic.parse("10:30am")..(Chronic.parse("12pm"))),
          event_factory("third", Chronic.parse("1:30pm")..(Chronic.parse("2:30pm"))),
          event_factory("fourth", Chronic.parse("3pm")..(Chronic.parse("5pm"))),
          event_factory("fifth", Chronic.parse("5:30pm")..(Chronic.parse("6pm"))),
          event_factory("fourth", Chronic.parse("6:30pm")..(Chronic.parse("7pm"))),
        ]
      end

      before do
        events.each { |e| allow(e).to receive(:accepted?).and_return(true) }
      end

      describe "meeting-length" do
        context "30m" do
          let(:options) { {"meeting-length" => "30m"} }

          let(:expected_avails) do
            {
              date => [
                event_factory("available", Chronic.parse("10am")..Chronic.parse("10:30am")),
                event_factory("available", Chronic.parse("12pm")..Chronic.parse("1:30pm")),
                event_factory("available", Chronic.parse("2:30pm")..Chronic.parse("3pm")),
                event_factory("available", Chronic.parse("5pm")..Chronic.parse("5:30pm")),
              ]
            }
          end

          it "finds blocks of time 30m or longer" do
            found_avails = scheduler.available_blocks time_range

            expect(found_avails.keys).to eq([date])
            expect(found_avails[date].length).to eq(expected_avails[date].length)
            found_avails[date].each_with_index do |found_avail, j|
              expect(found_avail.start).to eq(expected_avails[date][j].start)
              expect(found_avail.end).to eq(expected_avails[date][j].end)
            end
          end
        end

        context "60m" do
          let(:options) { {"meeting-length" => "60m"} }

          let(:expected_avails) do
            {
              date => [
                event_factory("available", Chronic.parse("12pm")..Chronic.parse("1:30pm")),
              ]
            }
          end

          it "finds blocks of time 60m or longer" do
            found_avails = scheduler.available_blocks time_range

            expect(found_avails.keys).to eq([date])
            expect(found_avails[date].length).to eq(expected_avails[date].length)
            found_avails[date].each_with_index do |found_avail, j|
              expect(found_avail.start).to eq(expected_avails[date][j].start)
              expect(found_avail.end).to eq(expected_avails[date][j].end)
            end
          end
        end
      end

      describe "start-of-day and end-of-day" do
        context "9-6" do
          let(:options) { {"start-of-day" => "9am", "end-of-day" => "6pm"} }

          let(:expected_avails) do
            {
              date => [
                event_factory("available", Chronic.parse("10am")..Chronic.parse("10:30am")),
                event_factory("available", Chronic.parse("12pm")..Chronic.parse("1:30pm")),
                event_factory("available", Chronic.parse("2:30pm")..Chronic.parse("3pm")),
                event_factory("available", Chronic.parse("5pm")..Chronic.parse("5:30pm")),
              ]
            }
          end

          it "finds blocks of time 30m or longer" do
            found_avails = scheduler.available_blocks time_range

            expect(found_avails.keys).to eq([date])
            expect(found_avails[date].length).to eq(expected_avails[date].length)
            found_avails[date].each_with_index do |found_avail, j|
              expect(found_avail.start).to eq(expected_avails[date][j].start)
              expect(found_avail.end).to eq(expected_avails[date][j].end)
            end
          end
        end

        context "8-7" do
          let(:options) { {"start-of-day" => "8am", "end-of-day" => "7pm"} }

          let(:expected_avails) do
            {
              date => [
                event_factory("available", Chronic.parse("8am")..Chronic.parse("8:30am")),
                event_factory("available", Chronic.parse("10am")..Chronic.parse("10:30am")),
                event_factory("available", Chronic.parse("12pm")..Chronic.parse("1:30pm")),
                event_factory("available", Chronic.parse("2:30pm")..Chronic.parse("3pm")),
                event_factory("available", Chronic.parse("5pm")..Chronic.parse("5:30pm")),
                event_factory("available", Chronic.parse("6pm")..Chronic.parse("6:30pm")),
              ]
            }
          end

          it "finds blocks of time 30m or longer" do
            found_avails = scheduler.available_blocks time_range

            expect(found_avails.keys).to eq([date])
            expect(found_avails[date].length).to eq(expected_avails[date].length)
            found_avails[date].each_with_index do |found_avail, j|
              expect(found_avail.start).to eq(expected_avails[date][j].start)
              expect(found_avail.end).to eq(expected_avails[date][j].end)
            end
          end
        end
      end
    end
  end
end
