HISTORY_LEN = 60   # 60 samples × 3s = 3 minutes

# Persistent history across re-renders
window.dlhist ||= {}

metrics = [
  {key: 'gpu0_temp',  label: 'Temp', max: 100,   unit: ' °C', color: '#88ff88', fmt: 'int'}
  {key: 'gpu0_fan',   label: 'Fan',  max: 100,   unit: '%',   color: '#50c8ff', fmt: 'int'}
  {key: 'gpu0_util',  label: 'Util', max: 100,   unit: '%',   color: '#7896ff', fmt: 'int'}
  {key: 'gpu0_mem',   label: 'VRAM', max: 12288, unit: ' MiB', color: '#c878dc', fmt: 'int'}
  {key: 'gpu0_power', label: 'Pwr',  max: 350,   unit: ' W',  color: '#ffb450', fmt: 'flt'}
  {key: 'gpu1_temp',  label: 'Temp', max: 100,   unit: ' °C', color: '#88ff88', fmt: 'int'}
  {key: 'gpu1_fan',   label: 'Fan',  max: 100,   unit: '%',   color: '#50c8ff', fmt: 'int'}
  {key: 'gpu1_util',  label: 'Util', max: 100,   unit: '%',   color: '#7896ff', fmt: 'int'}
  {key: 'gpu1_mem',   label: 'VRAM', max: 12288, unit: ' MiB', color: '#c878dc', fmt: 'int'}
  {key: 'gpu1_power', label: 'Pwr',  max: 350,   unit: ' W',  color: '#ffb450', fmt: 'flt'}
  {key: 'cpu_pkg',    label: 'Pkg',  max: 100,   unit: ' °C', color: '#ff8c50', fmt: 'int'}
  {key: 'cpu_max',    label: 'Max',  max: 100,   unit: ' °C', color: '#ff8c50', fmt: 'int'}
]

rowHtml = (m) ->
  """
    <div class="row">
      <div class="label">#{m.label}</div>
      <div class="bar"><div class="fill" id="bar-#{m.key}" style="background: #{m.color}"></div></div>
      <svg class="spark" id="spark-#{m.key}" viewBox="0 0 240 16" preserveAspectRatio="none">
        <polyline fill="none" stroke="#{m.color}" stroke-width="1.4" />
      </svg>
      <div class="value" id="val-#{m.key}">--</div>
    </div>
  """

groupHtml = (prefix) ->
  (rowHtml(m) for m in metrics when m.key.startsWith(prefix)).join('')

command: "ssh trainer /usr/local/bin/trainer-stats"

refreshFrequency: 3000

style: """
  top 290px
  left 0
  width 540px
  background rgba(16, 16, 21, 0.88)
  border-radius 8px
  padding 14px 18px
  font-family -apple-system, "Segoe UI", sans-serif
  color #fff
  box-shadow 0 8px 32px rgba(0, 0, 0, 0.4)

  h1
    margin 0
    font-size 14px
    font-weight 600
    color #50c8ff
    letter-spacing 0.5px

  .sub
    font-size 9px
    color #b4b4c8
    margin-bottom 10px

  .header
    margin-top 10px
    margin-bottom 4px
    font-size 11px
    font-weight 600
    color #78dcff
    letter-spacing 0.3px

    &.cpu
      color #ffb450

  .row
    display grid
    grid-template-columns 46px 90px 1fr 84px
    align-items center
    column-gap 10px
    height 20px

  .label
    font-size 10px
    color #b4b4c8

  .bar
    height 8px
    background rgba(40, 40, 50, 0.85)
    border-radius 2px
    overflow hidden

    .fill
      height 100%
      width 0%
      transition width 0.4s ease-out

  .spark
    height 18px
    width 100%
    background rgba(30, 30, 38, 0.7)
    border-radius 2px

  .value
    font-family Menlo, Consolas, monospace
    font-size 10px
    text-align right
    color #fff

  .footer
    margin-top 10px
    font-size 8px
    color #8c8ca0
    letter-spacing 0.2px

  .err
    color #ff6464
    font-size 10px
    padding 8px
"""

render: -> """
  <h1>DL-SERVER2</h1>
  <div class="sub">trainer @ 100.98.36.61</div>

  <div class="header">GPU 0  RTX 3080 Ti</div>
  #{groupHtml('gpu0')}

  <div class="header">GPU 1  RTX 3080 Ti</div>
  #{groupHtml('gpu1')}

  <div class="header cpu">CPU  i9-7900X  AIO</div>
  #{groupHtml('cpu')}

  <div class="footer">SSH every 3s · history 3 min · bar=current  line=trend</div>
  <div class="err" id="errmsg" style="display:none"></div>
"""

update: (output, domEl) ->
  errEl = domEl.querySelector("#errmsg")
  fields = output.trim().split(',')
  if fields.length < 12
    errEl.style.display = 'block'
    errEl.textContent = "fetch failed: #{output.trim().slice(0, 100)}"
    return
  errEl.style.display = 'none'

  values = {}
  for m, i in metrics
    values[m.key] = parseFloat(fields[i]) || 0

  for m in metrics
    val = values[m.key]
    pct = Math.min(100, Math.max(0, (val / m.max) * 100))

    bar = domEl.querySelector("#bar-#{m.key}")
    bar.style.width = "#{pct}%" if bar

    valEl = domEl.querySelector("#val-#{m.key}")
    if valEl
      txt = if m.fmt == 'flt' and val % 1 != 0
        "#{val.toFixed(1)}#{m.unit}"
      else
        "#{Math.round(val)}#{m.unit}"
      valEl.textContent = txt

    window.dlhist[m.key] ||= []
    h = window.dlhist[m.key]
    h.push(pct)
    h.shift() while h.length > HISTORY_LEN

    spark = domEl.querySelector("#spark-#{m.key}")
    if spark and h.length > 1
      poly = spark.querySelector('polyline')
      step = 240 / Math.max(HISTORY_LEN - 1, 1)
      offset = Math.max(0, HISTORY_LEN - h.length) * step
      pts = (h.map (v, i) -> "#{(offset + i * step).toFixed(1)},#{(15 - (v / 100) * 14).toFixed(1)}").join(' ')
      poly.setAttribute('points', pts)
