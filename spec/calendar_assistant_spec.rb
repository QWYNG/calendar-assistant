describe CalendarAssistant do
  describe "class methods" do
    describe ".date_range_cast" do
      context "given a Range of Times" do
        let(:start_time) { Chronic.parse "72 hours ago" }
        let(:end_time) { Chronic.parse "30 hours from now" }

        it "returns a Date range with the end date augmented for an all-day-event" do
          result = CalendarAssistant.date_range_cast(start_time..end_time)
          expect(result).to eq(start_time.to_date..(end_time.to_date + 1))
        end
      end
    end

    describe ".authorize" do
      let(:authorizer) { instance_double("Authorizer") }

      it "calls through to the Authorize class" do
        expect(CalendarAssistant::Authorizer).to(
          receive(:new).
            with("profile", instance_of(CalendarAssistant::Config::TokenStore)).
            and_return(authorizer)
        )
        expect(authorizer).to receive(:authorize)
        CalendarAssistant.authorize("profile")
      end
    end
  end

  describe "events" do
    let(:service) { instance_double("CalendarService") }
    let(:calendar) { instance_double("Calendar") }
    let(:config) { instance_double("CalendarAssistant::Config") }
    let(:token_store) { instance_double("CalendarAssistant::Config::TokenStore") }
    let(:event_repository) { instance_double("EventRepository") }
    let(:ca) { CalendarAssistant.new config, event_repository: event_repository }
    let(:event_array) { [instance_double("Event"), instance_double("Event")] }
    let(:events) { instance_double("Events", :items => event_array ) }
    let(:authorizer) { instance_double("Authorizer") }

    before do
      allow(CalendarAssistant::Authorizer).to receive(:new).and_return(authorizer)
      allow(config).to receive(:token_store).and_return(token_store)
      allow(config).to receive(:profile_name).and_return("profile-name")
      allow(authorizer).to receive(:service).and_return(service)
      allow(event_repository).to receive(:find).and_return([])
      allow(service).to receive(:get_calendar).and_return(calendar)
    end

    describe "#find_events" do
      let(:time) { Time.now.beginning_of_day..(Time.now + 1.day).end_of_day }

      it "calls through to the repository" do
        expect(event_repository).to receive(:find).with(time)
        ca.find_events(time)
      end
    end

    describe "#find_location_events" do
      let(:event_repository) { instance_double("EventRepository") }
      let(:ca) { CalendarAssistant.new config, event_repository: event_repository }
      let(:location_event) { instance_double("Event", :location_event? => true) }
      let(:other_event) { instance_double("Event", :location_event? => false) }
      let(:events) { [location_event, other_event].shuffle }

      it "selects location events from event repository find" do
        time = Time.now.beginning_of_day..(Time.now + 1.day).end_of_day

        expect(event_repository).to receive(:find).with(time).and_return(events)

        result = ca.find_location_events time
        expect(result).to eq([location_event])
      end
    end

    describe "#create_location_event" do
      let(:new_event) do
        CalendarAssistant::Event.new(instance_double("GCal::Event", {
                          id: SecureRandom.uuid,
                          start: new_event_start,
                          end: new_event_end
                        }))
      end

      before do
        allow(service).to receive(:list_events).and_return(nil)
      end

      let(:new_event_start) { GCal::EventDateTime.new date: new_event_start_date }
      let(:new_event_end) { GCal::EventDateTime.new date: (new_event_end_date + 1.day) } # always one day later than actual end

      context "called with a Date" do
        let(:new_event_start_date) { Date.today }
        let(:new_event_end_date) { new_event_start_date }

        it "creates an appropriately-titled transparent all-day event" do
          attributes = {
              start: new_event_start.date,
              end: new_event_end.date,
              summary: "#{CalendarAssistant::EMOJI_WORLDMAP}  WFH",
              transparency: GCal::Event::Transparency::TRANSPARENT
          }

          expect(event_repository).to receive(:create).with(attributes).and_return(new_event)

          response = ca.create_location_event CalendarAssistant::CLIHelpers.parse_datespec("today"), "WFH"
          expect(response[:created]).to eq([new_event])
        end
      end

      context "called with a Date Range" do
        let(:new_event_start_date) { Date.parse("2019-09-03") }
        let(:new_event_end_date) { Date.parse("2019-09-05") }

        it "creates an appropriately-titled transparent all-day event" do
          attributes = {
              start: new_event_start.date,
              end: new_event_end.date,
              summary: "#{CalendarAssistant::EMOJI_WORLDMAP}  WFH",
              transparency: GCal::Event::Transparency::TRANSPARENT
          }

          expect(event_repository).to receive(:create).with(attributes).and_return(new_event)

          response = ca.create_location_event new_event_start_date..new_event_end_date, "WFH"
          expect(response[:created]).to eq([new_event])
        end
      end

      context "when there's a pre-existing location event" do
        let(:existing_event_start) { GCal::EventDateTime.new date: existing_event_start_date }
        let(:existing_event_end) { GCal::EventDateTime.new date: (existing_event_end_date + 1.day) } # always one day later than actual end

        let(:new_event_start_date) { Date.parse("2019-09-03") }
        let(:new_event_end_date) { Date.parse("2019-09-05") }

        let(:existing_event) do
          CalendarAssistant::Event.new(instance_double("GCal::Event", {
                            id: SecureRandom.uuid,
                            start: existing_event_start,
                            end: existing_event_end
                          }))
        end

        before do
          attributes = {
              start: new_event_start.date,
              end: new_event_end.date,
              summary: "#{CalendarAssistant::EMOJI_WORLDMAP}  WFH",
              transparency: GCal::Event::Transparency::TRANSPARENT
          }

          expect(event_repository).to receive(:create).with(attributes).and_return(new_event)
          expect(ca).to receive(:find_location_events).and_return([existing_event])
        end

        context "when the new event is entirely within the range of the pre-existing event" do
          let(:existing_event_start_date) { new_event_start_date }
          let(:existing_event_end_date) { new_event_end_date }

          it "removes the pre-existing event" do
            expect(event_repository).to receive(:delete).with(existing_event)

            response = ca.create_location_event new_event_start_date..new_event_end_date, "WFH"
            expect(response[:created]).to eq([new_event])
            expect(response[:deleted]).to eq([existing_event])
          end
        end

        context "when the new event overlaps the start of the pre-existing event" do
          let(:existing_event_start_date) { Date.parse("2019-09-04") }
          let(:existing_event_end_date) { Date.parse("2019-09-06") }

          it "shrinks the pre-existing event" do
            expect(event_repository).to receive(:update).with(existing_event, start: existing_event_end_date)

            response = ca.create_location_event new_event_start_date..new_event_end_date, "WFH"
            expect(response[:created]).to eq([new_event])
            expect(response[:modified]).to eq([existing_event])
          end
        end

        context "when the new event overlaps the end of the pre-existing event" do
          let(:existing_event_start_date) { Date.parse("2019-09-02") }
          let(:existing_event_end_date) { Date.parse("2019-09-04") }

          it "shrinks the pre-existing event" do
            expect(event_repository).to receive(:update).with(existing_event, end: new_event_start_date )

            response = ca.create_location_event new_event_start_date..new_event_end_date, "WFH"
            expect(response[:created]).to eq([new_event])
            expect(response[:modified]).to eq([existing_event])
          end
        end

        context "when the new event is completely overlapped by the pre-existing event" do
          let(:existing_event_start_date) { Date.parse("2019-09-02") }
          let(:existing_event_end_date) { Date.parse("2019-09-06") }

          it "shrinks the pre-existing event" do
            expect(event_repository).to receive(:update).with(existing_event, start: existing_event_end_date)

            response = ca.create_location_event new_event_start_date..new_event_end_date, "WFH"
            expect(response[:created]).to eq([new_event])
            expect(response[:modified]).to eq([existing_event])
          end
        end
      end
    end

    describe "#availability" do
      let(:scheduler) { instance_double(CalendarAssistant::Scheduler) }
      let(:time_range) { instance_double("time range") }

      it "creates a scheduler and invokes #available_blocks" do
        expect(CalendarAssistant::Scheduler).to receive(:new).
                                                  with(ca, config: config).
                                                  and_return(scheduler)
        expect(scheduler).to receive(:available_blocks).with(time_range).and_return(events)

        response = ca.availability(time_range)

        expect(response).to eq(events)
      end
    end
  end

  describe "event formatting" do
    describe "#event_description" do it end
    describe "#event_date_description" do it end
  end
end
