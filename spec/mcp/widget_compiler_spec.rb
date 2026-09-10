require "rails_helper"

RSpec.describe WidgetCompiler do
  describe "player engine script" do
    let(:script) { WidgetCompiler::WidgetContext.new.player_engine_script }

    it "defines every player unit the facade depends on, in dependency order" do
      order = %w[handoffPlan SessionKeeper ElementStream WebAudioBackend GaplessEngine Gapless5]
      positions = order.map { |name| script.index(/^(class|const) #{name}\b/) }
      expect(positions).to all(be_a(Integer))
      expect(positions).to eq(positions.sort)
    end

    it "strips module syntax so the script runs as a classic script" do
      expect(script).not_to match(/^(import|export) /)
    end
  end
end
