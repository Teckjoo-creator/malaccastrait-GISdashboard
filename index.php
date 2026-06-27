<?php
// ============================================================
//  HORMUZ MARITIME API  —  api/index.php
//  Routes:
//    GET /api/?endpoint=vessels            → all live vessels + position
//    GET /api/?endpoint=vessel&id=X        → single vessel detail
//    GET /api/?endpoint=traffic            → hourly traffic (today)
//    GET /api/?endpoint=monthly&year=2025  → monthly transits 2025
//    GET /api/?endpoint=incidents          → active incidents/alerts
//    GET /api/?endpoint=kpi               → dashboard KPI summary
//    GET /api/?endpoint=cargo             → cargo breakdown counts
//    GET /api/?endpoint=flags             → flag state distribution
//    POST /api/?endpoint=update_position  → update a vessel position
//    POST /api/?endpoint=add_incident     → log a new incident
// ============================================================

require_once __DIR__ . '/db.php';

$endpoint = $_GET['endpoint'] ?? '';

switch ($endpoint) {
    case 'vessels':       getVessels();       break;
    case 'vessel':        getVessel();        break;
    case 'traffic':       getTraffic();       break;
    case 'monthly':       getMonthly();       break;
    case 'incidents':     getIncidents();     break;
    case 'kpi':           getKPI();           break;
    case 'cargo':         getCargo();         break;
    case 'flags':         getFlags();         break;
    case 'update_position': updatePosition(); break;
    case 'add_incident':  addIncident();      break;
    default:
        jsonResponse(['error' => 'Unknown endpoint. Valid: vessels, vessel, traffic, monthly, incidents, kpi, cargo, flags'], 404);
}

// ────────────────────────────────────────────────────────────
//  GET /vessels — all vessels with latest position & voyage
// ────────────────────────────────────────────────────────────
function getVessels(): void {
    $pdo = getDB();
    $sql = "
        SELECT
            v.id, v.mmsi, v.imo, v.vessel_name, v.vessel_type,
            v.flag_state, v.dwt, v.year_built, v.owner, v.call_sign,
            p.latitude, p.longitude, p.speed_kts, p.heading_deg,
            p.course_deg, p.nav_status, p.timestamp AS position_time,
            voy.cargo_type, voy.origin_port, voy.dest_port,
            voy.direction, voy.eta
        FROM vessels v
        LEFT JOIN vessel_positions p ON p.id = (
            SELECT id FROM vessel_positions
            WHERE vessel_id = v.id
            ORDER BY timestamp DESC LIMIT 1
        )
        LEFT JOIN voyages voy ON voy.vessel_id = v.id AND voy.is_active = 1
        ORDER BY v.id
    ";
    $rows = $pdo->query($sql)->fetchAll();

    // Cast numeric fields
    foreach ($rows as &$r) {
        $r['id']          = (int)$r['id'];
        $r['dwt']         = $r['dwt']         ? (int)$r['dwt']         : null;
        $r['year_built']  = $r['year_built']  ? (int)$r['year_built']  : null;
        $r['latitude']    = $r['latitude']    ? (float)$r['latitude']  : null;
        $r['longitude']   = $r['longitude']   ? (float)$r['longitude'] : null;
        $r['speed_kts']   = $r['speed_kts']   ? (float)$r['speed_kts'] : 0.0;
        $r['heading_deg'] = $r['heading_deg'] ? (int)$r['heading_deg'] : 0;
    }
    jsonResponse(['success' => true, 'count' => count($rows), 'data' => $rows]);
}

// ────────────────────────────────────────────────────────────
//  GET /vessel?id=X — single vessel + incident history
// ────────────────────────────────────────────────────────────
function getVessel(): void {
    $id = (int)($_GET['id'] ?? 0);
    if ($id < 1) { jsonResponse(['error' => 'id required'], 400); }
    $pdo = getDB();

    $v = $pdo->prepare("SELECT * FROM vessels WHERE id = ?");
    $v->execute([$id]);
    $vessel = $v->fetch();
    if (!$vessel) { jsonResponse(['error' => 'Vessel not found'], 404); }

    // Last 10 positions
    $pos = $pdo->prepare("
        SELECT latitude, longitude, speed_kts, heading_deg, nav_status, timestamp
        FROM vessel_positions WHERE vessel_id = ?
        ORDER BY timestamp DESC LIMIT 10
    ");
    $pos->execute([$id]);
    $vessel['recent_positions'] = $pos->fetchAll();

    // Active voyage
    $voy = $pdo->prepare("SELECT * FROM voyages WHERE vessel_id = ? AND is_active = 1 LIMIT 1");
    $voy->execute([$id]);
    $vessel['voyage'] = $voy->fetch() ?: null;

    // Incidents
    $inc = $pdo->prepare("
        SELECT incident_type, severity, description, reported_at, is_active
        FROM incidents WHERE vessel_id = ?
        ORDER BY reported_at DESC LIMIT 5
    ");
    $inc->execute([$id]);
    $vessel['incidents'] = $inc->fetchAll();

    jsonResponse(['success' => true, 'data' => $vessel]);
}

// ────────────────────────────────────────────────────────────
//  GET /traffic — hourly traffic (defaults to most recent data)
// ────────────────────────────────────────────────────────────
function getTraffic(): void {
    $pdo = getDB();
    
    // 1. Find the most recent date we actually have data for
    $latestDate = $pdo->query("SELECT MAX(stat_date) FROM traffic_stats")->fetchColumn();
    
    // 2. Use the requested date, or default to the latest available date
    $date = $_GET['date'] ?? ($latestDate ?: date('Y-m-d'));
    
    $stmt = $pdo->prepare("
        SELECT stat_hour, vessel_count, outbound_count, inbound_count,
               avg_speed_kts, oil_volume_kbd
        FROM traffic_stats
        WHERE stat_date = ?
        ORDER BY stat_hour ASC
    ");
    $stmt->execute([$date]);
    $rows = $stmt->fetchAll();
    
    foreach ($rows as &$r) {
        $r['stat_hour']      = (int)$r['stat_hour'];
        $r['vessel_count']   = (int)$r['vessel_count'];
        $r['outbound_count'] = (int)$r['outbound_count'];
        $r['inbound_count']  = (int)$r['inbound_count'];
        $r['avg_speed_kts']  = $r['avg_speed_kts']  ? (float)$r['avg_speed_kts']  : null;
        $r['oil_volume_kbd'] = $r['oil_volume_kbd'] ? (float)$r['oil_volume_kbd'] : null;
    }
    jsonResponse(['success' => true, 'date' => $date, 'data' => $rows]);
}

// ────────────────────────────────────────────────────────────
//  GET /monthly — monthly transits (default: current year)
// ────────────────────────────────────────────────────────────
function getMonthly(): void {
    $pdo  = getDB();
    $year = (int)($_GET['year'] ?? date('Y'));
    $stmt = $pdo->prepare("
        SELECT transit_month, total_transits, total_vlcc, total_suezmax,
               total_aframax, total_lng, total_lpg, avg_daily_kbd
        FROM monthly_transits
        WHERE transit_year = ?
        ORDER BY transit_month ASC
    ");
    $stmt->execute([$year]);
    $rows = $stmt->fetchAll();
    foreach ($rows as &$r) {
        $r['transit_month']   = (int)$r['transit_month'];
        $r['total_transits']  = (int)$r['total_transits'];
        $r['total_vlcc']      = (int)$r['total_vlcc'];
        $r['total_suezmax']   = (int)$r['total_suezmax'];
        $r['total_aframax']   = (int)$r['total_aframax'];
        $r['total_lng']       = (int)$r['total_lng'];
        $r['total_lpg']       = (int)$r['total_lpg'];
        $r['avg_daily_kbd']   = $r['avg_daily_kbd'] ? (float)$r['avg_daily_kbd'] : null;
    }
    jsonResponse(['success' => true, 'year' => $year, 'data' => $rows]);
}

// ────────────────────────────────────────────────────────────
//  GET /incidents — active incidents list
// ────────────────────────────────────────────────────────────
function getIncidents(): void {
    $pdo  = getDB();
    $only_active = ($_GET['active'] ?? '1') === '1';
    $where = $only_active ? 'WHERE i.is_active = 1' : '';
    $stmt = $pdo->query("
        SELECT i.id, i.incident_type, i.severity, i.latitude, i.longitude,
               i.description, i.reported_at, i.resolved_at, i.is_active,
               v.vessel_name, v.vessel_type, v.flag_state
        FROM incidents i
        LEFT JOIN vessels v ON v.id = i.vessel_id
        $where
        ORDER BY
            FIELD(i.severity,'critical','high','medium','low'),
            i.reported_at DESC
        LIMIT 50
    ");
    $rows = $stmt->fetchAll();
    foreach ($rows as &$r) {
        $r['id']        = (int)$r['id'];
        $r['is_active'] = (bool)$r['is_active'];
        $r['latitude']  = $r['latitude']  ? (float)$r['latitude']  : null;
        $r['longitude'] = $r['longitude'] ? (float)$r['longitude'] : null;
    }
    jsonResponse(['success' => true, 'count' => count($rows), 'data' => $rows]);
}

// ────────────────────────────────────────────────────────────
//  GET /kpi — dashboard summary numbers
// ────────────────────────────────────────────────────────────
function getKPI(): void {
    $pdo = getDB();

    $activeVessels = $pdo->query("
        SELECT COUNT(DISTINCT vessel_id) AS cnt
        FROM vessel_positions
        WHERE timestamp >= NOW() - INTERVAL 2 HOUR
          AND nav_status != 'alert'
    ")->fetch()['cnt'];

    $alertVessels = $pdo->query("
        SELECT COUNT(*) AS cnt FROM incidents WHERE is_active = 1
    ")->fetch()['cnt'];

    $detainedVessels = $pdo->query("
        SELECT COUNT(*) AS cnt FROM incidents
        WHERE is_active = 1 AND incident_type = 'Detention'
    ")->fetch()['cnt'];

    $avgSpeed = $pdo->query("
        SELECT ROUND(AVG(speed_kts), 1) AS avg_spd
        FROM vessel_positions
        WHERE timestamp >= NOW() - INTERVAL 1 HOUR
          AND nav_status = 'underway'
    ")->fetch()['avg_spd'];

    $oilToday = $pdo->query("
        SELECT ROUND(SUM(oil_volume_kbd) / 1000, 1) AS total_mbd
        FROM traffic_stats
        WHERE stat_date = CURDATE()
    ")->fetch()['total_mbd'];

    $incidentsMonth = $pdo->query("
        SELECT COUNT(*) AS cnt FROM incidents
        WHERE reported_at >= DATE_FORMAT(NOW(),'%Y-%m-01')
    ")->fetch()['cnt'];

    jsonResponse([
        'success'          => true,
        'active_vessels'   => (int)$activeVessels,
        'alert_count'      => (int)$alertVessels,
        'detained'         => (int)$detainedVessels,
        'avg_speed_kts'    => (float)($avgSpeed ?? 0),
        'oil_volume_mbd'   => (float)($oilToday ?? 0),
        'incidents_30d'    => (int)$incidentsMonth,
        'generated_at'     => date('Y-m-d H:i:s'),
    ]);
}

// ────────────────────────────────────────────────────────────
//  GET /cargo — cargo type breakdown from active voyages
// ────────────────────────────────────────────────────────────
function getCargo(): void {
    $pdo = getDB();
    $stmt = $pdo->query("
        SELECT cargo_type, COUNT(*) AS vessel_count
        FROM voyages
        WHERE is_active = 1
        GROUP BY cargo_type
        ORDER BY vessel_count DESC
    ");
    jsonResponse(['success' => true, 'data' => $stmt->fetchAll()]);
}

// ────────────────────────────────────────────────────────────
//  GET /flags — flag state distribution
// ────────────────────────────────────────────────────────────
function getFlags(): void {
    $pdo = getDB();
    $total = (int)$pdo->query("SELECT COUNT(*) FROM vessels")->fetchColumn();
    $stmt  = $pdo->query("
        SELECT flag_state, COUNT(*) AS count,
               ROUND(COUNT(*) * 100.0 / $total, 1) AS pct
        FROM vessels
        GROUP BY flag_state
        ORDER BY count DESC
    ");
    jsonResponse(['success' => true, 'total' => $total, 'data' => $stmt->fetchAll()]);
}

// ────────────────────────────────────────────────────────────
//  POST /update_position — upsert latest position for a vessel
//  Body: { vessel_id, latitude, longitude, speed_kts, heading_deg, nav_status }
// ────────────────────────────────────────────────────────────
function updatePosition(): void {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse(['error' => 'POST required'], 405);
    }
    $body = json_decode(file_get_contents('php://input'), true) ?? [];
    $required = ['vessel_id', 'latitude', 'longitude'];
    foreach ($required as $key) {
        if (!isset($body[$key])) {
            jsonResponse(['error' => "Missing field: $key"], 400);
        }
    }
    $pdo  = getDB();
    $stmt = $pdo->prepare("
        INSERT INTO vessel_positions (vessel_id, latitude, longitude, speed_kts, heading_deg, nav_status)
        VALUES (:vid, :lat, :lng, :spd, :hdg, :status)
    ");
    $stmt->execute([
        ':vid'    => (int)$body['vessel_id'],
        ':lat'    => (float)$body['latitude'],
        ':lng'    => (float)$body['longitude'],
        ':spd'    => (float)($body['speed_kts']   ?? 0),
        ':hdg'    => (int)  ($body['heading_deg']  ?? 0),
        ':status' => $body['nav_status'] ?? 'unknown',
    ]);
    jsonResponse(['success' => true, 'inserted_id' => (int)$pdo->lastInsertId()]);
}

// ────────────────────────────────────────────────────────────
//  POST /add_incident
//  Body: { vessel_id, incident_type, severity, latitude, longitude, description }
// ────────────────────────────────────────────────────────────
function addIncident(): void {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse(['error' => 'POST required'], 405);
    }
    $body = json_decode(file_get_contents('php://input'), true) ?? [];
    $pdo  = getDB();
    $stmt = $pdo->prepare("
        INSERT INTO incidents (vessel_id, incident_type, severity, latitude, longitude, description)
        VALUES (:vid, :type, :sev, :lat, :lng, :desc)
    ");
    $stmt->execute([
        ':vid'  => isset($body['vessel_id']) ? (int)$body['vessel_id'] : null,
        ':type' => $body['incident_type'] ?? 'Other',
        ':sev'  => $body['severity']      ?? 'medium',
        ':lat'  => isset($body['latitude'])  ? (float)$body['latitude']  : null,
        ':lng'  => isset($body['longitude']) ? (float)$body['longitude'] : null,
        ':desc' => $body['description']   ?? null,
    ]);
    jsonResponse(['success' => true, 'incident_id' => (int)$pdo->lastInsertId()]);
}
