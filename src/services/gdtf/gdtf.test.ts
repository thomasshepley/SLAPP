import { describe, expect, it } from 'vitest';
import { XMLParser } from 'fast-xml-parser';
import { mapGdtfAttribute } from './attributeMap';
import { gdtfDocToFixture } from './parse';

describe('mapGdtfAttribute', () => {
  it('maps intensity', () => {
    expect(mapGdtfAttribute('Dimmer')).toBe('intensity');
  });

  it('maps additive RGB', () => {
    expect(mapGdtfAttribute('ColorAdd_R')).toBe('red');
    expect(mapGdtfAttribute('ColorAdd_G')).toBe('green');
    expect(mapGdtfAttribute('ColorAdd_B')).toBe('blue');
    expect(mapGdtfAttribute('ColorAdd_W')).toBe('white');
    expect(mapGdtfAttribute('ColorAdd_A')).toBe('amber');
  });

  it('maps CMY and CCT', () => {
    expect(mapGdtfAttribute('ColorSub_C')).toBe('cyan');
    expect(mapGdtfAttribute('ColorTemperature')).toBe('cct');
    expect(mapGdtfAttribute('CTO')).toBe('cct');
  });

  it('maps movement and optics', () => {
    expect(mapGdtfAttribute('Pan')).toBe('pan');
    expect(mapGdtfAttribute('Tilt')).toBe('tilt');
    expect(mapGdtfAttribute('Zoom')).toBe('zoom');
    expect(mapGdtfAttribute('Focus')).toBe('focus');
  });

  it('maps prefixed gobo / colour wheel / shutter', () => {
    expect(mapGdtfAttribute('Gobo1')).toBe('gobo');
    expect(mapGdtfAttribute('Gobo2WheelSpin')).toBe('gobo');
    expect(mapGdtfAttribute('Color1')).toBe('colourWheel');
    expect(mapGdtfAttribute('Shutter1Strobe')).toBe('shutter');
    expect(mapGdtfAttribute('StrobeFrequency')).toBe('shutter');
  });

  it('falls back to other for unknown / empty', () => {
    expect(mapGdtfAttribute('SomethingWeird')).toBe('other');
    expect(mapGdtfAttribute(undefined)).toBe('other');
    expect(mapGdtfAttribute('')).toBe('other');
  });
});

const SAMPLE_GDTF = `<?xml version="1.0" encoding="UTF-8"?>
<GDTF DataVersion="1.1">
  <FixtureType Manufacturer="ACME" Name="Test Wash 200" FixtureTypeID="abc-123" RefinedFixtureType="LED Wash">
    <PhysicalDescriptions>
      <CRIs>
        <CRIGroup ColorTemperature="6500">
          <CRI CES="CES01" ColorRenderingIndex="95"/>
          <CRI CES="CES02" ColorRenderingIndex="93"/>
        </CRIGroup>
      </CRIs>
    </PhysicalDescriptions>
    <Geometries>
      <Geometry Name="Base" PowerConsumption="200">
        <Geometry Name="Head">
          <Beam BeamAngle="25" Name="Beam"/>
        </Geometry>
      </Geometry>
    </Geometries>
    <DMXModes>
      <DMXMode Name="16-bit RGBW">
        <DMXChannels>
          <DMXChannel DMXBreak="1" Offset="1,2" Geometry="Head">
            <LogicalChannel Attribute="Dimmer">
              <ChannelFunction Attribute="Dimmer" Name="Dimmer"/>
            </LogicalChannel>
          </DMXChannel>
          <DMXChannel DMXBreak="1" Offset="3" Geometry="Head">
            <LogicalChannel Attribute="ColorAdd_R">
              <ChannelFunction Attribute="ColorAdd_R" Name="Red"/>
            </LogicalChannel>
          </DMXChannel>
          <DMXChannel DMXBreak="1" Offset="4" Geometry="Head">
            <LogicalChannel Attribute="ColorAdd_G">
              <ChannelFunction Attribute="ColorAdd_G" Name="Green"/>
            </LogicalChannel>
          </DMXChannel>
          <DMXChannel DMXBreak="1" Offset="5" Geometry="Head">
            <LogicalChannel Attribute="ColorAdd_B">
              <ChannelFunction Attribute="ColorAdd_B" Name="Blue"/>
            </LogicalChannel>
          </DMXChannel>
          <DMXChannel DMXBreak="1" Offset="6" Geometry="Head">
            <LogicalChannel Attribute="ColorAdd_W">
              <ChannelFunction Attribute="ColorAdd_W" Name="White"/>
            </LogicalChannel>
          </DMXChannel>
        </DMXChannels>
      </DMXMode>
      <DMXMode Name="CCT">
        <DMXChannels>
          <DMXChannel DMXBreak="1" Offset="1" Geometry="Head">
            <LogicalChannel Attribute="Dimmer">
              <ChannelFunction Attribute="Dimmer" Name="Dimmer"/>
            </LogicalChannel>
          </DMXChannel>
          <DMXChannel DMXBreak="1" Offset="2" Geometry="Head">
            <LogicalChannel Attribute="ColorTemperature">
              <ChannelFunction Attribute="ColorTemperature" Name="CCT"/>
            </LogicalChannel>
          </DMXChannel>
        </DMXChannels>
      </DMXMode>
    </DMXModes>
  </FixtureType>
</GDTF>`;

describe('gdtfDocToFixture', () => {
  const parser = new XMLParser({
    ignoreAttributes: false,
    attributeNamePrefix: '@_',
    isArray: (name) =>
      ['DMXMode', 'DMXChannel', 'LogicalChannel', 'ChannelFunction', 'Geometry', 'Beam'].includes(name),
  });

  const { fixture, warnings } = gdtfDocToFixture(parser.parse(SAMPLE_GDTF));

  it('extracts manufacturer and model', () => {
    expect(fixture.manufacturer).toBe('ACME');
    expect(fixture.model).toBe('Test Wash 200');
  });

  it('extracts both modes with correct channel counts', () => {
    expect(fixture.modes).toHaveLength(2);
    const rgbw = fixture.modes.find((m) => m.name === '16-bit RGBW')!;
    // Offsets 1..6, with 1,2 being a 16-bit dimmer → footprint 6
    expect(rgbw.channelCount).toBe(6);
    const cct = fixture.modes.find((m) => m.name === 'CCT')!;
    expect(cct.channelCount).toBe(2);
  });

  it('maps the 16-bit dimmer and colour channels', () => {
    const rgbw = fixture.modes.find((m) => m.name === '16-bit RGBW')!;
    const dimmer = rgbw.channels.find((c) => c.attribute === 'intensity')!;
    expect(dimmer.offset).toBe(0);
    expect(dimmer.resolution).toBe(16);
    expect(rgbw.channels.map((c) => c.attribute)).toEqual([
      'intensity', 'red', 'green', 'blue', 'white',
    ]);
  });

  it('detects colour mixing, beam angle, power and CRI', () => {
    expect(fixture.colour.hasColourMixing).toBe(true);
    expect(fixture.beam.angleDeg).toBe(25);
    expect(fixture.modes[0]!.powerW).toBe(200);
    expect(fixture.colour.cri).toBe(94); // (95 + 93) / 2 rounded
  });

  it('flags source as gdtf-share with the type id', () => {
    expect(fixture.source.origin).toBe('gdtf-share');
    expect(fixture.source.gdtfFixtureTypeId).toBe('abc-123');
  });

  it('produces no warnings for a complete fixture', () => {
    expect(warnings).toHaveLength(0);
  });
});
