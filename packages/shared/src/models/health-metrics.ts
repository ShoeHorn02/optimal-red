export type HealthMetricType = 'heart_rate' | 'distance' | 'elevation' | 'calories';
export type MetricSource = 'watchos' | 'ios' | 'manual' | 'backend';

export interface HealthMetric {
  id: string;
  userId: string;
  type: HealthMetricType;
  value: number;
  unit: string;
  recordedAt: Date;
  source: MetricSource;
  syncedAt?: Date;
}

export interface HealthMetricBatch {
  userId: string;
  timestamp: string;
  changes: HealthMetric[];
}

export interface DailyMetrics {
  date: string;
  heartRate?: {
    min: number;
    max: number;
    avg: number;
    samples: number;
  };
  distance: number;
  elevation: number;
  calories: number;
}

export const HEALTH_METRIC_UNITS: Record<HealthMetricType, string> = {
  heart_rate: 'bpm',
  distance: 'km',
  elevation: 'm',
  calories: 'kcal',
};

export const NORMAL_HEART_RATE_RANGES = {
  resting: { min: 60, max: 100 },
  light_activity: { min: 100, max: 140 },
  moderate_activity: { min: 140, max: 160 },
  vigorous_activity: { min: 160, max: 220 },
};
