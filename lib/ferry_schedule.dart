import 'package:flutter/material.dart';

class FerrySchedule {
  final List<TimeOfDay> ferryTimes;

  FerrySchedule() : ferryTimes = _initializeFerryTimes();

  /// Helper method to initialize ferry times
  static List<TimeOfDay> _initializeFerryTimes() {
    return [
      const TimeOfDay(hour: 7, minute: 35),
      const TimeOfDay(hour: 9, minute: 35),
      const TimeOfDay(hour: 10, minute: 45),
      const TimeOfDay(hour: 12, minute: 25),
      const TimeOfDay(hour: 13, minute: 05),
      const TimeOfDay(hour: 15, minute: 15),
      const TimeOfDay(hour: 16, minute: 45),
      const TimeOfDay(hour: 18, minute: 25),
      const TimeOfDay(hour: 19, minute: 05),
      const TimeOfDay(hour: 21, minute: 00),
    ];
  }

  // Function to find all ferry departure times that happen after the user departure time
  List<TimeOfDay> getFerryDeparturesAfter(TimeOfDay userDeparture) {
    return ferryTimes.where((ferryTime) {
      return ferryTime.hour > userDeparture.hour ||
             (ferryTime.hour == userDeparture.hour && ferryTime.minute > userDeparture.minute);
    }).toList();
  }

  // Function to get ferry departures in a time range
  List<TimeOfDay> getFerryDeparturesInRange(TimeOfDay departure) {
    TimeOfDay startRange = addMinutes(departure, -90); // 1.5 hours before
    TimeOfDay endRange = addMinutes(departure, 90);    // 1.5 hours after

    print(startRange);
    print(departure);
    return ferryTimes.where((ferryTime) {
      return _isTimeInRange(ferryTime, startRange, endRange);
    }).toList();
  }

  // Check if a time is within the range
  bool _isTimeInRange(TimeOfDay time, TimeOfDay start, TimeOfDay end) {
    final timeInMinutes = time.hour * 60 + time.minute;
    final startInMinutes = start.hour * 60 + start.minute;
    final endInMinutes = end.hour * 60 + end.minute;

    if (endInMinutes < startInMinutes) {
      return timeInMinutes >= startInMinutes || timeInMinutes <= endInMinutes;
    } else {
      return timeInMinutes >= startInMinutes && timeInMinutes <= endInMinutes;
    }
  }
}

// Utility function to add minutes to a TimeOfDay
TimeOfDay addMinutes(TimeOfDay time, int minutes) {
  int totalMinutes = (time.hour * 60 + time.minute) + minutes;

  // Handle cases where totalMinutes might be negative
  if (totalMinutes < 0) {
    totalMinutes = (24 * 60) + totalMinutes; 
  }

  int newHour = (totalMinutes ~/ 60) % 24;
  int newMinutes = totalMinutes % 60;

  return TimeOfDay(hour: newHour, minute: newMinutes);
}

